#ifndef RX_PWM3_H
#define RX_PWM3_H

#include <stdint.h>

#define RX_PWM3_INPUT_RATE 15360000U
#define RX_PWM3_SYMBOL_RATE 10000U
#define RX_PWM3_CAPTURE_TUPLES 491520U
#define RX_PWM3_PAYLOAD_SYMBOLS 8U
#define RX_PWM3_MAX_FRAMES 16U

typedef struct {
    uint8_t user;
    uint8_t symbols[RX_PWM3_PAYLOAD_SYMBOLS];
} rx_pwm3_frame;

typedef struct {
    int carrier_hz;
    unsigned count;
    rx_pwm3_frame frames[RX_PWM3_MAX_FRAMES];
} rx_pwm3_result;

/* Process one 32 ms window of interleaved signed I1,Q1,I2,Q2 at 15.36 MS/s.
 * RX1 is the RF path. Uses static workspace and runs once in the foreground. */
void rx_pwm3_decode(const int16_t (*iq)[4], rx_pwm3_result *result,
                    void (*service)(void));

#endif
