#ifndef GPIO_RIS_H
#define GPIO_RIS_H

#include "xgpio.h"

#ifdef __cplusplus
extern "C" {
#endif

#define GPIO_RIS_MODE_SHIFT      29U
#define GPIO_RIS_OUTPUT_MASK     0x01FFFFFFU
#define GPIO_RIS_CHANNEL         1U

enum gpio_ris_mode {
    GPIO_RIS_MODE_MONITOR = 4, /* 100: debounced key controls all outputs. */
    GPIO_RIS_MODE_PS = 5,      /* 101: bits 24:0 drive individual outputs. */
    GPIO_RIS_MODE_AUTO = 7     /* 111: RTL generates the 1 MHz square wave. */
};

enum gpio_ris_status {
    GPIO_RIS_OK = 0,
    GPIO_RIS_ERR_ARGUMENT = -1,
    GPIO_RIS_ERR_NOT_READY = -2,
    GPIO_RIS_ERR_CONFIG = -3
};

typedef struct {
    XGpio gpio;
    u32 last_command;
    u32 ps_values; /* Last PS pattern, retained across mode changes. */
    u8 ready;
} gpio_ris_device;

/* Requires the matching bitstream/PS initialization. Uses AXI GPIO channel 1
 * at the BSP's XPAR_AXI_GPIO_RIS_CTL_BASEADDR (current XSA: 0x80010000).
 * init selects MONITOR with reserved bits clear; no AUTO demo is run.
 * APIs are not thread-safe: the caller exclusively owns this AXI GPIO.
 */
int gpio_ris_init(gpio_ris_device *dev);
int gpio_ris_pack(enum gpio_ris_mode mode, u32 pins, u32 *command);
int gpio_ris_write(gpio_ris_device *dev, enum gpio_ris_mode mode, u32 pins);
int gpio_ris_set_mode(gpio_ris_device *dev, enum gpio_ris_mode mode);
/* These two APIs select PS mode. set_pin uses 1-based row/column in [1,5]. */
int gpio_ris_set_outputs(gpio_ris_device *dev, u32 pins);
int gpio_ris_set_pin(gpio_ris_device *dev, unsigned row, unsigned column,
                     unsigned value);
/* Returns the last command issued by software, NOT physical output readback. */
int gpio_ris_get_command(const gpio_ris_device *dev, u32 *command);
const char *gpio_ris_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
