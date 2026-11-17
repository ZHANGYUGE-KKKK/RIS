#include "rx_pwm3_service.h"
#include "rx_pwm3.h"
#include "rx_network.h"
#include "rx_uplink.h"
#include "capture_store.h"
#include <stdio.h>
#include <string.h>

_Static_assert(RX_PWM3_INPUT_RATE == CAPTURE_SAMPLE_RATE, "PWM sample rate mismatch");
_Static_assert((RX_PWM3_CAPTURE_TUPLES * CAPTURE_TUPLE_BYTES) % CAPTURE_PACKET_BYTES == 0,
               "PWM window must contain whole DMA packets");

static int16_t iq[RX_PWM3_CAPTURE_TUPLES][4] __attribute__((aligned(64)));
static char owned_capture[17];
static XTime next_capture;
static int enabled, last_result, uplink_result, carrier_hz;
static unsigned windows, frames, reports, sequence;

static int process_capture(void)
{
    rx_pwm3_result decoded;
    char json[RX_UPLINK_MAX_PAYLOAD];
    unsigned used;

    for (unsigned offset = 0; offset < sizeof(iq); offset += CAPTURE_CHUNK_BYTES) {
        unsigned bytes = sizeof(iq) - offset;
        if (bytes > CAPTURE_CHUNK_BYTES) bytes = CAPTURE_CHUNK_BYTES;
        if (capture_store_read(owned_capture, offset, bytes, (uint8_t *)iq + offset))
            return -1;
        rx_network_poll();
    }
    rx_pwm3_decode(iq, &decoded, rx_network_poll);
    carrier_hz = decoded.carrier_hz;
    ++windows;
    frames += decoded.count;
    if (!decoded.count) return 0;

    int count = snprintf(json, sizeof(json),
        "{\"type\":\"pwm3\",\"capture_id\":\"%s\",\"carrier_hz\":%d,\"frames\":[",
        owned_capture, carrier_hz);
    if (count < 0 || (unsigned)count >= sizeof(json)) return -2;
    used = (unsigned)count;
    for (unsigned n = 0; n < decoded.count; ++n) {
        char symbols[RX_PWM3_PAYLOAD_SYMBOLS + 1U];
        for (unsigned j = 0; j < RX_PWM3_PAYLOAD_SYMBOLS; ++j)
            symbols[j] = (char)('0' + decoded.frames[n].symbols[j]);
        symbols[RX_PWM3_PAYLOAD_SYMBOLS] = '\0';
        count = snprintf(json + used, sizeof(json) - used,
            "%s{\"user\":%u,\"symbols\":\"%s\"}", n ? "," : "",
            (unsigned)decoded.frames[n].user, symbols);
        if (count < 0 || (unsigned)count >= sizeof(json) - used) return -2;
        used += (unsigned)count;
    }
    if (sizeof(json) - used < 2U) return -2;
    memcpy(json + used, "]}", 2U);
    uplink_result = rx_uplink_send(++sequence, 1U, (const uint8_t *)json, used + 2U);
    if (!uplink_result) ++reports;
    return 0;
}

int rx_pwm3_start(void)
{
    if (enabled) return 0;
    if (capture_store.state == CAP_STORE_UNAVAILABLE ||
        capture_store.state == CAP_STORE_CAPTURING ||
        capture_store.state == CAP_STORE_READY || !capture_store.reset_verified)
        return -1;
    enabled = 1;
    XTime_GetTime(&next_capture);
    last_result = uplink_result = 0;
    return 0;
}

int rx_pwm3_running(void)
{
    return enabled;
}

void rx_pwm3_stop(void)
{
    enabled = 0;
    if (owned_capture[0] && !strcmp(owned_capture, capture_store.id)) {
        if (capture_store.state == CAP_STORE_CAPTURING) capture_store_abort();
        if (capture_store.state == CAP_STORE_READY) capture_store_release(owned_capture);
    }
    owned_capture[0] = '\0';
}

void rx_pwm3_poll(void)
{
    XTime now;

    if (!enabled) return;
    if (owned_capture[0]) {
        if (capture_store.state == CAP_STORE_CAPTURING) return;
        if (strcmp(owned_capture, capture_store.id)) {
            rx_pwm3_stop();
            last_result = -3;
            return;
        }
        if (capture_store.state != CAP_STORE_READY) {
            last_result = capture_store.result;
            rx_pwm3_stop();
            return;
        }
        last_result = process_capture();
        capture_store_release(owned_capture);
        owned_capture[0] = '\0';
        XTime_GetTime(&now);
        next_capture = now + COUNTS_PER_SECOND;
        return;
    }

    XTime_GetTime(&now);
    if (now < next_capture || (capture_store.state != CAP_STORE_EMPTY &&
                               capture_store.state != CAP_STORE_FAILED)) return;
    last_result = capture_store_begin(sizeof(iq));
    if (last_result) {
        rx_pwm3_stop();
        return;
    }
    memcpy(owned_capture, capture_store.id, sizeof(owned_capture));
}

int rx_pwm3_status(char *out, unsigned capacity)
{
    return snprintf(out, capacity,
        "{\"ok\":true,\"type\":\"pwm3_status\",\"enabled\":%s,"
        "\"symbol_hz\":%u,\"windows\":%u,\"frames\":%u,\"reports_queued\":%u,"
        "\"carrier_hz\":%d,\"capture_result\":%d,\"uplink_result\":%d,"
        "\"link_up\":%s,\"init_error\":%d}\n",
        enabled ? "true" : "false", RX_PWM3_SYMBOL_RATE, windows, frames, reports,
        carrier_hz, last_result, uplink_result, rx_uplink_link_up() ? "true" : "false",
        rx_uplink_init_error());
}
