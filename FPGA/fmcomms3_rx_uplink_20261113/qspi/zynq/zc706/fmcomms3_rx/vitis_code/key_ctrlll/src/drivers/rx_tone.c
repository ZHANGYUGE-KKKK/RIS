#include "rx_tone.h"
#include <string.h>

/* cos/sin(2*pi/2^k), k=1..14. Double recurrence avoids accumulated phase
 * error in the Hann window and FFT twiddles without a runtime math library.
 */
static const double roots[14][2] = {
    {-1.0, 0.0}, {0.0, 1.0},
    {0.7071067811865475244, 0.7071067811865475244},
    {0.9238795325112867561, 0.3826834323650897717},
    {0.9807852804032304491, 0.1950903220161282678},
    {0.9951847266721968862, 0.0980171403295606020},
    {0.9987954562051723927, 0.0490676743274180143},
    {0.9996988186962042201, 0.0245412285229122880},
    {0.9999247018391445409, 0.0122715382857199261},
    {0.9999811752826011427, 0.0061358846491544754},
    {0.9999952938095761715, 0.0030679567629659763},
    {0.9999988234517019099, 0.0015339801862847656},
    {0.9999997058628822192, 0.0007669903187427045},
    {0.9999999264657178511, 0.0003834951875713956}
};

static uint32_t integer_sqrt(uint32_t value)
{
    uint32_t bit = 1U << 30, root = 0U;
    while (bit > value) bit >>= 2;
    while (bit) {
        if (value >= root + bit) {
            value -= root + bit;
            root = (root >> 1) + bit;
        } else root >>= 1;
        bit >>= 2;
    }
    return root;
}

static void fft(rx_tone_workspace *w)
{
    uint32_t i, j = 0U, bit, length, stage, start, offset;
    for (i = 1U; i < RX_TONE_SAMPLES; ++i) {
        bit = RX_TONE_SAMPLES >> 1;
        while (j & bit) { j ^= bit; bit >>= 1; }
        j ^= bit;
        if (i < j) {
            float x = w->real[i], y = w->imag[i];
            w->real[i] = w->real[j]; w->imag[i] = w->imag[j];
            w->real[j] = x; w->imag[j] = y;
        }
    }
    for (length = 2U, stage = 0U; length <= RX_TONE_SAMPLES;
         length <<= 1, ++stage) {
        double cr = roots[stage][0], ci = -roots[stage][1];
        for (start = 0U; start < RX_TONE_SAMPLES; start += length) {
            double wr = 1.0, wi = 0.0;
            for (offset = 0U; offset < length / 2U; ++offset) {
                uint32_t a = start + offset, b = a + length / 2U;
                double xr = wr*w->real[b] - wi*w->imag[b];
                double xi = wr*w->imag[b] + wi*w->real[b];
                double next = wr*cr - wi*ci;
                w->real[b] = (float)(w->real[a] - xr);
                w->imag[b] = (float)(w->imag[a] - xi);
                w->real[a] = (float)(w->real[a] + xr);
                w->imag[a] = (float)(w->imag[a] + xi);
                wi = wr*ci + wi*cr; wr = next;
            }
        }
    }
}

static double bin_power(const rx_tone_workspace *w, uint32_t bin)
{
    return (double)w->real[bin]*w->real[bin] +
           (double)w->imag[bin]*w->imag[bin];
}

static int32_t interpolated_hz(const rx_tone_workspace *w, uint32_t peak)
{
    double before = bin_power(w, (peak + RX_TONE_SAMPLES - 1U) % RX_TONE_SAMPLES);
    double after = bin_power(w, (peak + 1U) % RX_TONE_SAMPLES);
    double denominator = before - 2.0*bin_power(w, peak) + after;
    double position = denominator != 0.0 ? 0.5*(before-after)/denominator : 0.0;
    if (position < -0.5) position = -0.5;
    if (position > 0.5) position = 0.5;
    position += peak <= RX_TONE_SAMPLES/2U ? (double)peak : (double)peak-RX_TONE_SAMPLES;
    return (int32_t)(position*RX_TONE_SAMPLE_HZ/RX_TONE_SAMPLES);
}

int rx_tone_band_peak(const rx_tone_workspace *w, uint32_t expected,
                      uint32_t half_width, rx_tone_band_result *r)
{
    uint32_t n, peak = 0U;
    double total = 0.0, strongest = -1.0, band = 0.0;
    if (!w || !r || !half_width || expected <= half_width ||
        expected > RX_TONE_SAMPLE_HZ/2U ||
        half_width > RX_TONE_SAMPLE_HZ/2U-expected) return -1;
    for (n = 0U; n < RX_TONE_SAMPLES; ++n) {
        uint32_t distance = n <= RX_TONE_SAMPLES/2U ? n : RX_TONE_SAMPLES-n;
        double frequency = (double)distance*RX_TONE_SAMPLE_HZ/RX_TONE_SAMPLES;
        double power = bin_power(w, n);
        total += power;
        if (frequency >= expected-half_width && frequency <= expected+half_width &&
            power > strongest) { strongest = power; peak = n; }
    }
    if (strongest < 0.0) return -1;
    for (n = 0U; n < 5U; ++n)
        band += bin_power(w, (peak + RX_TONE_SAMPLES + n - 2U) % RX_TONE_SAMPLES);
    r->peak_hz = interpolated_hz(w, peak);
    r->power_permille = total > 0.0 ? (uint32_t)(1000.0*band/total + 0.5) : 0U;
    if (r->power_permille > 1000U) r->power_permille = 1000U;
    return 0;
}

int rx_tone_analyze(const int16_t samples[][4], uint32_t count,
                    uint32_t channel, rx_tone_workspace *w,
                    float *spectrum, rx_tone_result *r)
{
    int64_t sums[2] = {0, 0};
    uint32_t n, component, peak = 0U;
    double means[2], energy = 0.0, total = 0.0, strongest = -1.0;
    double wc = 1.0, ws = 0.0, band = 0.0;
    if (!samples || !w || !r || count != RX_TONE_SAMPLES || channel > 1U)
        return -1;
    memset(r, 0, sizeof(*r));
    for (component = 0U; component < 2U; ++component) {
        r->minimum[component] = 32767; r->maximum[component] = -32768;
    }
    for (n = 0U; n < count; ++n) {
        uint32_t clipped = 0U;
        for (component = 0U; component < 2U; ++component) {
            int32_t v = samples[n][channel*2U + component];
            sums[component] += v;
            if (v < r->minimum[component]) r->minimum[component] = v;
            if (v > r->maximum[component]) r->maximum[component] = v;
            if (v < -2048 || v > 2047) ++r->malformed;
            if (v <= -2048 || v >= 2047) clipped = 1U;
        }
        r->clipped += clipped;
    }
    for (component = 0U; component < 2U; ++component) {
        means[component] = (double)sums[component] / count;
        r->mean[component] = (int32_t)means[component];
    }
    for (n = 0U; n < count; ++n) {
        double x = samples[n][channel*2U] - means[0];
        double y = samples[n][channel*2U+1U] - means[1];
        double weight = 0.5 - 0.5*wc;
        double next = wc*roots[13][0] - ws*roots[13][1];
        energy += x*x + y*y;
        w->real[n] = (float)(x*weight); w->imag[n] = (float)(y*weight);
        ws = wc*roots[13][1] + ws*roots[13][0]; wc = next;
    }
    r->ac_power_counts = (uint32_t)(energy/count + 0.5);
    r->rms_counts = integer_sqrt(r->ac_power_counts);
    fft(w);
    for (n = 0U; n < count; ++n) {
        double p = bin_power(w, n);
        uint32_t distance = n <= count/2U ? n : count-n;
        total += p;
        if (spectrum) spectrum[n] = (float)p;
        /* Ignore the first +/-100 kHz only when locating the RF tone.
         * Low-frequency energy remains in the purity denominator. */
        if (distance * (double)RX_TONE_SAMPLE_HZ / count >= 100000.0 &&
            p > strongest) { strongest = p; peak = n; }
    }
    for (n = 0U; n < 5U; ++n)
        band += bin_power(w, (peak + count + n - 2U) % count);
    r->band_power = band; r->peak_bin = peak;
    if (total > 0.0) r->purity_permille = (uint32_t)(1000.0*band/total + 0.5);
    if (r->purity_permille > 1000U) r->purity_permille = 1000U;
    r->peak_hz = interpolated_hz(w, peak);
    return 0;
}

uint32_t rx_tone_check(rx_tone_result *r, const float *background, uint32_t expected)
{
    uint32_t n, frequency = r->peak_hz < 0 ? (uint32_t)-r->peak_hz : (uint32_t)r->peak_hz;
    uint32_t difference = frequency > expected ? frequency-expected : expected-frequency;
    double floor = 1.0, ratio;
    r->failures = 0U;
    if (r->malformed) r->failures |= RX_TONE_FORMAT;
    if (r->clipped*1000U > RX_TONE_SAMPLES) r->failures |= RX_TONE_CLIPPED;
    if (r->ac_power_counts < 4U) r->failures |= RX_TONE_WEAK;
    if (r->purity_permille < RX_TONE_MIN_PURITY) r->failures |= RX_TONE_IMPURE;
    if (difference > RX_TONE_FREQUENCY_TOLERANCE) r->failures |= RX_TONE_FREQUENCY;
    if (background) {
        for (n = 0U; n < 5U; ++n)
            floor += background[(r->peak_bin + RX_TONE_SAMPLES + n - 2U) % RX_TONE_SAMPLES];
        ratio = 100.0*r->band_power/floor;
        r->rise_x100 = ratio < 999999.0 ? (uint32_t)ratio : 999999U;
        if (r->rise_x100 < 400U) r->failures |= RX_TONE_BACKGROUND;
    } else { r->rise_x100 = 0U; r->failures |= RX_TONE_BACKGROUND; }
    return r->failures;
}

uint32_t rx_tone_check_shift(const rx_tone_result *a, const rx_tone_result *b)
{
    int64_t shift = (int64_t)b->peak_hz - a->peak_hz;
    if (shift < 0) shift = -shift;
    shift -= 1000000;
    if (shift < 0) shift = -shift;
    if ((a->peak_hz < 0) != (b->peak_hz < 0) || shift > RX_TONE_SHIFT_TOLERANCE)
        return RX_TONE_SHIFT;
    return 0U;
}
