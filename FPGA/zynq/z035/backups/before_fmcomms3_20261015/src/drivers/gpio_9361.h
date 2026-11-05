#ifndef GPIO_9361_H
#define GPIO_9361_H

#include "xgpio.h"

#ifdef __cplusplus
extern "C" {
#endif

#define GPIO_9361_ARM_CHANNEL        1U
#define GPIO_9361_STATUS_CHANNEL     2U
#define GPIO_9361_ARM_MASK           0x01U
#define GPIO_9361_READY_MASK         0x01U
#define GPIO_9361_FRAME_LOCKED_MASK  0x02U
#define GPIO_9361_ACTIVE_MASK        0x04U
#define GPIO_9361_OVERFLOW_MASK      0x08U
#define GPIO_9361_FRAME_ERROR_MASK   0x10U
#define GPIO_9361_DELAY_ERROR_MASK   0x20U
#define GPIO_9361_ERROR_MASK         0x38U
#define GPIO_9361_STATUS_MASK        0x3FU

enum gpio_9361_status {
    GPIO_9361_OK = 0,
    GPIO_9361_ERR_ARGUMENT = -1,
    GPIO_9361_ERR_NOT_READY = -2,
    GPIO_9361_ERR_CONFIG = -3,
    GPIO_9361_ERR_CAPTURE = -4,
    GPIO_9361_ERR_RESET_REQUIRED = -5,
    GPIO_9361_ERR_TIMEOUT = -6
};

typedef struct {
    XGpio gpio;
    u32 last_status;
    u8 ready;
    u8 armed;
} gpio_9361_device;

/* axi_gpio_9361 @0x80020000: channel 1 is a single ARM output;
 * channel 2 contains six independent synchronized status levels in bits 5:0.
 * init writes ARM=0 but does NOT reset the receiver or either AXIS FIFO.
 * The caller exclusively owns this GPIO; no concurrent/interrupt access.
 */
int gpio_9361_init(gpio_9361_device *dev);
int gpio_9361_get_status(gpio_9361_device *dev, u32 *status);
int gpio_9361_check_ready(gpio_9361_device *dev);
int gpio_9361_wait_ready(gpio_9361_device *dev, u32 timeout_us);
/* Only call after the DMA has valid receive descriptors and is running. */
int gpio_9361_arm(gpio_9361_device *dev);
/* Clears the command bit only. The RTL remains armed until system/PL reset;
 * this is neither a stop nor a reset API. Does not clear dev->armed.
 */
int gpio_9361_release_arm(gpio_9361_device *dev);
const char *gpio_9361_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
