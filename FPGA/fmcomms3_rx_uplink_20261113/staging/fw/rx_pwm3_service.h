#ifndef RX_PWM3_SERVICE_H
#define RX_PWM3_SERVICE_H

int rx_pwm3_start(void);
void rx_pwm3_stop(void);
void rx_pwm3_poll(void);
int rx_pwm3_status(char *out, unsigned capacity);

#endif
