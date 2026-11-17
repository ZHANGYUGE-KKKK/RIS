#include "rx_tone.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static int16_t samples[RX_TONE_SAMPLES][4];
static rx_tone_workspace work;
static float background[RX_TONE_SAMPLES];
static uint32_t random_state = 0x5318249U;

static int noise(void)
{
    random_state ^= random_state << 13;
    random_state ^= random_state >> 17;
    random_state ^= random_state << 5;
    return (int)(random_state % 9U) - 4;
}

static void generate(double frequency, double amplitude, double leakage,
                     int real_only, int clipping)
{
    unsigned n;
    const double tau = 6.2831853071795864769;
    memset(samples, 0, sizeof(samples));
    for (n = 0U; n < RX_TONE_SAMPLES; ++n) {
        double phase = tau*frequency*n/RX_TONE_SAMPLE_HZ + 0.7;
        double leak = tau*960000.0*n/RX_TONE_SAMPLE_HZ;
        double i = amplitude*cos(phase) + leakage*cos(leak) + 200.0 + noise();
        double q = (real_only ? 0.0 : amplitude*sin(phase)) + leakage*sin(leak) - 100.0 + noise();
        if (clipping) {
            if (i > 2047.0) i = 2047.0;
            if (i < -2048.0) i = -2048.0;
            if (q > 2047.0) q = 2047.0;
            if (q < -2048.0) q = -2048.0;
        }
        samples[n][0] = (int16_t)i; samples[n][1] = (int16_t)q;
        samples[n][2] = (int16_t)noise(); samples[n][3] = (int16_t)noise();
    }
}

static rx_tone_result analyze(int keep_background)
{
    rx_tone_result r;
    assert(rx_tone_analyze(samples, RX_TONE_SAMPLES, 0U, &work,
                           keep_background ? background : NULL, &r) == 0);
    return r;
}

int main(void)
{
    rx_tone_result a, b, r;
    rx_tone_band_result band;
    unsigned sign;
    for (sign = 0U; sign < 2U; ++sign) {
        double direction = sign ? -1.0 : 1.0;
        generate(0.0, 0.0, 40.0, 0, 0); r = analyze(1);
        generate(direction*954500.0, 300.0, 40.0, 0, 0); a = analyze(0);
        assert(rx_tone_check(&a, background, 1000000U) == 0U);
        assert(fabs(a.peak_hz-direction*954500.0) < 200.0);
        generate(direction*1954450.0, 300.0, 40.0, 0, 0); b = analyze(0);
        assert(rx_tone_check(&b, background, 2000000U) == 0U);
        assert(rx_tone_check_shift(&a, &b) == 0U);
        printf("PASS: sign=%d independent-LO offset, noise, DC, TX leakage; f=%d/%d purity=%u/%u\n",
               sign ? -1 : 1, a.peak_hz, b.peak_hz, a.purity_permille, b.purity_permille);
    }
    generate(1000000.0, 300.0, 0.0, 0, 0); r = analyze(1);
    generate(1000000.0, 300.0, 0.0, 0, 0); a = analyze(0);
    assert(rx_tone_check(&a, background, 1000000U) & RX_TONE_BACKGROUND);
    assert(rx_tone_check_shift(&a, &a) & RX_TONE_SHIFT);
    puts("PASS: unchanged internal tone fails OFF/ON contrast and tracking");

    generate(0.0, 0.0, 0.0, 0, 0); r = analyze(1);
    assert(rx_tone_check(&r, background, 1000000U) & RX_TONE_IMPURE);
    generate(1000000.0, 300.0, 0.0, 1, 0); r = analyze(0);
    assert(rx_tone_check(&r, background, 1000000U) & RX_TONE_IMPURE);
    generate(3000000.0, 300.0, 0.0, 0, 0); r = analyze(0);
    assert(rx_tone_check(&r, background, 1000000U) & RX_TONE_FREQUENCY);
    generate(1000000.0, 0.2, 0.0, 0, 0); r = analyze(0);
    assert(rx_tone_check(&r, background, 1000000U) & RX_TONE_IMPURE);
    puts("PASS: noise, real-only/corrupt I/Q, wrong frequency, below-noise input rejected");

    generate(1000000.0, 3000.0, 0.0, 0, 1); r = analyze(0);
    assert(rx_tone_check(&r, background, 1000000U) & RX_TONE_CLIPPED);
    generate(1000000.0, 300.0, 0.0, 0, 0); samples[42][0] = 4096;
    r = analyze(0);
    assert(rx_tone_check(&r, background, 1000000U) & RX_TONE_FORMAT);
    memset(samples, 0, sizeof(samples)); r = analyze(0);
    assert(rx_tone_check(&r, background, 1000000U) & RX_TONE_WEAK);
    assert(rx_tone_analyze(samples, 100U, 0U, &work, NULL, &r) != 0);
    assert(rx_tone_analyze(samples, RX_TONE_SAMPLES, 2U, &work, NULL, &r) != 0);
    puts("PASS: clipping, malformed sign extension, zeros and invalid inputs rejected");

    generate(1000000.0, 300.0, 0.0, 0, 0); a = analyze(0);
    generate(-2000000.0, 300.0, 0.0, 0, 0); b = analyze(0);
    assert(rx_tone_check_shift(&a, &b) & RX_TONE_SHIFT);
    puts("PASS: inconsistent I/Q frequency direction rejected");

    for (sign = 0U; sign < 2U; ++sign) {
        double direction = sign ? -1.0 : 1.0;
        generate(direction*1967800.0, 60.0, 300.0, 0, 0); r = analyze(0);
        assert(fabs(r.peak_hz-960000.0) < 200.0);
        assert(rx_tone_band_peak(&work, 2000000U, 100000U, &band) == 0);
        assert(fabs(band.peak_hz-direction*1967800.0) < 200.0);
        assert(band.power_permille > 30U && band.power_permille < 50U);
        assert(rx_tone_band_peak(&work, 1000000U, 100000U, &band) == 0);
        assert(fabs(band.peak_hz-960000.0) < 200.0);
    }
    assert(rx_tone_band_peak(&work, 100U, 200U, &band) != 0);
    assert(rx_tone_band_peak(&work, RX_TONE_SAMPLE_HZ, 100000U, &band) != 0);
    puts("PASS: expected-band diagnostic finds weak RF tone beneath strong 960 kHz leakage, both IQ signs");
    return 0;
}
