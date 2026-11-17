#include "rx_pwm3.h"
#include <math.h>
#include <string.h>

#define TAU 6.2831853071795864769
#define DECIMATION 8U
#define SAMPLES (RX_PWM3_CAPTURE_TUPLES / DECIMATION)
#define SYMBOL_SAMPLES (RX_PWM3_INPUT_RATE / (DECIMATION * RX_PWM3_SYMBOL_RATE))
#define PHASE_BLOCK (4U * SYMBOL_SAMPLES)
#define BLOCKS (SAMPLES / PHASE_BLOCK)
#define CARRIER_TUPLES 16384U
#define FRAME_SYMBOLS 20U

typedef struct { float i, q; } complex_sample;
typedef struct { float start, width; } pulse;

static complex_sample samples[SAMPLES];
static float metric[SAMPLES];
static float phase[BLOCKS];

static double carrier_estimate(const int16_t (*iq)[4])
{
    static const unsigned lags[] = {1U, 8U, 64U, 512U, 4096U, 12000U};
    double hz = 0.0;

    /* Squaring removes the near-antipodal PWM state reversal. Resolve the
     * wrapped phase at increasingly long lags using the previous estimate. */
    for (unsigned step = 0; step < sizeof(lags) / sizeof(lags[0]); ++step) {
        unsigned lag = lags[step];
        double re = 0.0, im = 0.0;

        for (unsigned n = 0; n + lag < CARRIER_TUPLES; ++n) {
            float ai = iq[n][0], aq = iq[n][1];
            float bi = iq[n + lag][0], bq = iq[n + lag][1];
            float r = ai * bi + aq * bq;
            float j = ai * bq - aq * bi;

            re += (double)r * r - (double)j * j;
            im += 2.0 * r * j;
        }
        double turns = atan2(im, re) / TAU;
        hz = (round(hz * lag / RX_PWM3_INPUT_RATE - turns) + turns) *
             RX_PWM3_INPUT_RATE / lag;
    }
    return hz * 0.5;
}

static void mix(const int16_t (*iq)[4], double carrier, void (*service)(void))
{
    double angle = -TAU * carrier / RX_PWM3_INPUT_RATE;
    float ci = (float)cos(angle), cq = (float)sin(angle);
    float osc_i = 1.0f, osc_q = 0.0f;

    for (unsigned n = 0; n < SAMPLES; ++n) {
        float re = 0.0f, im = 0.0f;

        for (unsigned k = 0; k < DECIMATION; ++k) {
            float i = iq[n * DECIMATION + k][0], q = iq[n * DECIMATION + k][1];
            float next_i = osc_i * ci - osc_q * cq;

            re += i * osc_i - q * osc_q;
            im += i * osc_q + q * osc_i;
            osc_q = osc_i * cq + osc_q * ci;
            osc_i = next_i;
        }
        samples[n] = (complex_sample){re / DECIMATION, im / DECIMATION};
        if ((n & 1023U) == 1023U) {
            float gain = 1.0f / sqrtf(osc_i * osc_i + osc_q * osc_q);
            osc_i *= gain;
            osc_q *= gain;
            if (service) service();
        }
    }
}

static void project_states(void (*service)(void))
{
    for (unsigned block = 0; block < BLOCKS; ++block) {
        float i = 0.0f, q = 0.0f, re = 0.0f, im = 0.0f;
        const complex_sample *src = samples + block * PHASE_BLOCK;

        for (unsigned k = 0; k < PHASE_BLOCK; ++k) {
            i += src[k].i;
            q += src[k].q;
            re += src[k].i * src[k].i - src[k].q * src[k].q;
            im += 2.0f * src[k].i * src[k].q;
        }
        /* Principal axis of the two IQ clusters, after removing their mean.
         * Unwrap the doubled angle before halving to keep a fixed polarity. */
        float angle = atan2f(im - 2.0f * i * q / PHASE_BLOCK,
                            re - (i * i - q * q) / PHASE_BLOCK);
        if (block) {
            float previous = 2.0f * phase[block - 1U];
            angle += (float)TAU * roundf((previous - angle) / (float)TAU);
        }
        phase[block] = 0.5f * angle;
    }
    for (unsigned n = 0; n < SAMPLES; ++n) {
        float index = ((float)n + 0.5f) / PHASE_BLOCK - 0.5f;
        float angle = phase[0];

        if (index >= BLOCKS - 1U) angle = phase[BLOCKS - 1U];
        else if (index > 0.0f) {
            unsigned block = (unsigned)index;
            angle = phase[block] + (phase[block + 1U] - phase[block]) * (index - block);
        }
        metric[n] = samples[n].i * cosf(angle) + samples[n].q * sinf(angle);
        if (service && (n & 1023U) == 1023U) service();
    }
}

static float decision_threshold(float *hysteresis)
{
    float low = 0.0f, high = 0.0f;

    for (unsigned n = 0; n < SAMPLES; ++n) {
        low = fminf(low, metric[n]);
        high = fmaxf(high, metric[n]);
    }
    for (unsigned pass = 0; pass < 5U; ++pass) {
        float sum[2] = {0.0f, 0.0f};
        unsigned count[2] = {0U, 0U};
        float middle = (low + high) * 0.5f;

        for (unsigned n = 0; n < SAMPLES; ++n) {
            unsigned state = metric[n] >= middle;
            sum[state] += metric[n];
            ++count[state];
        }
        if (!count[0] || !count[1]) break;
        low = sum[0] / count[0];
        high = sum[1] / count[1];
    }
    *hysteresis = 0.1f * (high - low);
    return 0.5f * (high + low);
}

static unsigned crc12(const uint8_t symbols[FRAME_SYMBOLS])
{
    unsigned reg = 0;
    for (unsigned n = 0; n < FRAME_SYMBOLS; ++n) {
        for (int bit = 2; bit >= 0; --bit) {
            unsigned feedback = (reg >> 11) ^ ((symbols[n] >> bit) & 1U);
            reg = ((reg << 1) & 0xfffU) ^ (feedback ? 0x80fU : 0U);
        }
    }
    return reg;
}

static void decode_frame(const pulse window[FRAME_SYMBOLS], rx_pwm3_result *result)
{
    static const uint8_t identities[3][4] = {
        {0, 7, 7, 0}, {0, 0, 7, 7}, {7, 0, 0, 7}
    };
    static const uint8_t calibration[4] = {0, 7, 0, 7};
    uint8_t symbols[FRAME_SYMBOLS];

    if (fabsf(window[19].start - window[0].start - 19.0f * SYMBOL_SAMPLES) > 6.0f)
        return;
    for (unsigned n = 1; n < FRAME_SYMBOLS; ++n) {
        if (fabsf(window[n].start - window[n - 1U].start - SYMBOL_SAMPLES) > 8.0f)
            return;
    }

    float lo = (window[12].width + window[14].width) * 0.5f;
    float hi = (window[13].width + window[15].width) * 0.5f;
    if (lo < 40.0f || lo > 56.0f || hi - lo < 60.0f || hi - lo > 77.0f ||
        fabsf(window[12].width - window[14].width) > 5.0f ||
        fabsf(window[13].width - window[15].width) > 5.0f)
        return;
    for (unsigned n = 0; n < FRAME_SYMBOLS; ++n) {
        float value = (window[n].width - lo) * 7.0f / (hi - lo);
        int nearest = (int)roundf(value);

        if (nearest < 0 || nearest > 7 || fabsf(nearest - value) > 0.48f)
            return;
        symbols[n] = (uint8_t)nearest;
    }
    if (memcmp(symbols + 12U, calibration, sizeof(calibration)) || crc12(symbols))
        return;

    for (unsigned user = 0; user < 3U; ++user) {
        if (!memcmp(symbols, identities[user], sizeof(identities[user]))) {
            rx_pwm3_frame *frame = &result->frames[result->count++];
            frame->user = (uint8_t)(user + 1U);
            memcpy(frame->symbols, symbols + 4U, sizeof(frame->symbols));
            return;
        }
    }
}

static void scan_polarity(float threshold, float hysteresis, int one,
                          rx_pwm3_result *result, void (*service)(void))
{
    pulse window[FRAME_SYMBOLS];
    unsigned count = 0, crossing = 0;
    int state = metric[0] >= threshold;
    float rise = -1.0f;

    for (unsigned n = 1; n < SAMPLES && result->count < RX_PWM3_MAX_FRAMES; ++n) {
        if (service && (n & 4095U) == 0U) service();
        if ((metric[n] >= threshold) == state) {
            crossing = 0;
            continue;
        }
        if (!crossing) crossing = n;
        if (fabsf(metric[n] - threshold) < hysteresis) continue;
        state = !state;

        float edge = crossing - 1U +
            (threshold - metric[crossing - 1U]) / (metric[crossing] - metric[crossing - 1U]);
        if (state == one) {
            rise = edge;
        } else if (rise >= 0.0f && edge - rise > 25.0f && edge - rise < 155.0f) {
            if (count == FRAME_SYMBOLS) {
                memmove(window, window + 1U, (FRAME_SYMBOLS - 1U) * sizeof(window[0]));
                --count;
            }
            window[count++] = (pulse){rise, edge - rise};
            if (count == FRAME_SYMBOLS) {
                unsigned previous = result->count;
                decode_frame(window, result);
                if (previous != result->count) count = 0;
            }
        }
        crossing = 0;
    }
}

void rx_pwm3_decode(const int16_t (*iq)[4], rx_pwm3_result *result,
                    void (*service)(void))
{
    rx_pwm3_result other = {0};
    float hysteresis;

    memset(result, 0, sizeof(*result));
    double carrier = carrier_estimate(iq);
    if (service) service();
    mix(iq, carrier, service);
    project_states(service);
    float threshold = decision_threshold(&hysteresis);
    if (hysteresis > 0.0f) {
        scan_polarity(threshold, hysteresis, 0, result, service);
        scan_polarity(threshold, hysteresis, 1, &other, service);
        if (other.count > result->count) *result = other;
    }
    result->carrier_hz = (int)round(carrier);
}
