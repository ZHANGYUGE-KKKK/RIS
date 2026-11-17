#include "rx_control.h"
#include "rx_network.h"
#include "capture_store.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdint.h>

static int number(const char *s, u32 *v)
{
    char *end;
    unsigned long value;
    if (!s || !*s || *s == '-' || *s == '+') return -1;
    errno = 0; value = strtoul(s, &end, 10);
    if (errno || *end || value > UINT32_MAX) return -1;
    *v = (u32)value; return 0;
}
void rx_control_poll(void)
{
    char command[RX_NET_COMMAND_BYTES], *word[6], *p;
    char *out = (char *)rx_network_frame();
    u32 ticket, a = 0U, b = 0U;
    unsigned count = 0U;
    int n, rc = -1;
    capture_store_poll();
    if (capture_store_urgent()) return;
    rx_network_poll();
    if (!rx_network_take_request(command, &ticket)) return;
    p = strtok(command, " \t");
    while (p && count < 6U) { word[count++] = p; p = strtok(NULL, " \t"); }
    if (!count || count == 6U || p) goto bad;
    if (count == 1U && (!strcmp(word[0], "STATUS") || !strcmp(word[0], "HELLO"))) {
        n = capture_store_json(out, RX_NET_FRAME_BYTES);
        /* Add transport diagnostics to the same JSON object. */
        if (n > 2 && (u32)n < RX_NET_FRAME_BYTES - 160U) {
            n -= 2;
            n += snprintf(out + n, RX_NET_FRAME_BYTES - (u32)n,
                ",\"link_mbps\":%u,\"log_overruns\":%u,\"console_port\":5000}\n",
                (unsigned)rx_network_link_mbps(), (unsigned)rx_network_log_overruns());
        }
        goto reply;
    }
    if (count == 1U && !strcmp(word[0], "DEBUG")) {
        n = capture_store_debug_json(out, 8192U);
        if (n <= 0) goto bad;
        goto reply;
    }
    if (count == 2U && !strcmp(word[0], "CAPTURE") && !number(word[1], &a)) {
        rc = capture_store_begin(a);
        if (!rc) { n = capture_store_json(out, RX_NET_FRAME_BYTES); goto reply; }
    } else if (count == 2U && !strcmp(word[0], "RELEASE")) {
        rc = capture_store_release(word[1]);
    } else if (count == 1U && !strcmp(word[0], "ABORT")) {
        capture_store_abort(); rc = 0;
    } else if (count == 2U && !strcmp(word[0], "KEY") && strlen(word[1]) == 1U &&
               strchr("gsd012qtGSDQT", word[1][0])) {
        rc = rx_network_queue_key(word[1][0]);
    } else if (count == 4U && !strcmp(word[0], "READ") &&
               !number(word[2], &a) && !number(word[3], &b)) {
        unsigned char *payload = (unsigned char *)out + 1024U;
        if (b > CAPTURE_CHUNK_BYTES) goto bad;
        rc = capture_store_read(word[1], a, b, payload);
        if (!rc) {
            u32 crc = capture_crc32(payload, b);
            n = snprintf(out, 1024U,
                "{\"ok\":true,\"type\":\"data\",\"capture_id\":\"%s\","
                "\"offset\":%u,\"length\":%u,\"crc32\":\"%08x\"}\n",
                capture_store.id, (unsigned)a, (unsigned)b, (unsigned)crc);
            if (n <= 0 || n >= 1024) goto bad;
            memmove(out + n, payload, b);
            rx_network_reply(ticket, (u32)n + b);
            return;
        }
    }
    n = snprintf(out, RX_NET_FRAME_BYTES,
        "{\"ok\":%s,\"result\":%d,\"state\":\"%s\",\"capture_id\":\"%s\"}\n",
        rc ? "false" : "true", rc, capture_store_state_name(), capture_store.id);
    goto reply;
bad:
    n = snprintf(out, RX_NET_FRAME_BYTES,
        "{\"ok\":false,\"error\":\"invalid command or range\"}\n");
reply:
    if (n > 0 && (u32)n < RX_NET_FRAME_BYTES) rx_network_reply(ticket, (u32)n);
}
