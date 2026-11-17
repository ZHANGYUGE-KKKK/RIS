#ifndef RX_TONE_H
#define RX_TONE_H

/* Portable analysis of raw {I1,Q1,I2,Q2} signed 12-bit ADC tuples. */
#include <stdint.h>

#define RX_TONE_SAMPLES 16384U
#define RX_TONE_SAMPLE_HZ 15360000U
#define RX_TONE_MIN_PURITY 800U /* 80% of AC spectral power in five bins. */
#define RX_TONE_FREQUENCY_TOLERANCE 100000U /* Independent RF references. */
#define RX_TONE_SHIFT_TOLERANCE 10000U

enum rx_tone_failure {
    RX_TONE_FORMAT = 1U,
    RX_TONE_CLIPPED = 2U,
    RX_TONE_WEAK = 4U,
    RX_TONE_IMPURE = 8U,
    RX_TONE_FREQUENCY = 16U,
    RX_TONE_BACKGROUND = 32U,
    RX_TONE_SHIFT = 64U
};

typedef struct {
    float real[RX_TONE_SAMPLES];
    float imag[RX_TONE_SAMPLES];
} rx_tone_workspace;

typedef struct {
    int32_t peak_hz;
    uint32_t peak_bin, purity_permille, ac_power_counts, rms_counts;
    uint32_t malformed, clipped, rise_x100, failures;
    int32_t minimum[2], maximum[2], mean[2];
    double band_power;
} rx_tone_result;

typedef struct {
    int32_t peak_hz;
    uint32_t power_permille;
} rx_tone_band_result;

/* Workspace and optional power spectrum belong in PS DDR, not on the stack.
 * The caller must supply exactly RX_TONE_SAMPLES tuples from a completed DMA.
 * This function has no MMIO, RF configuration, allocation or libm dependency.
 */
int rx_tone_analyze(const int16_t samples[][4], uint32_t count,
                    uint32_t channel, rx_tone_workspace *work,
                    float *power_spectrum, rx_tone_result *result);
uint32_t rx_tone_check(rx_tone_result *result,
                       const float *background_spectrum, uint32_t expected_hz);
uint32_t rx_tone_check_shift(const rx_tone_result *first,
                             const rx_tone_result *second);
/* Diagnostic only: inspect an expected +/- frequency band in the last FFT.
 * A reported peak is not a signal-detection verdict; noise also has a maximum.
 */
int rx_tone_band_peak(const rx_tone_workspace *work, uint32_t expected_hz,
                      uint32_t half_width_hz, rx_tone_band_result *result);

#endif
