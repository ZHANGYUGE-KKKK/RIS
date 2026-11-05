/* PS M_AXI_GP1 -> axi_gpio_ris_ctl -> key_ctrl_55/gpio_cfg.
 * One 32-bit write carries mode[31:29], reserved[28:25]=0 and pins[24:0].
 */
#include "gpio_ris.h"

#include <string.h>
#include "xparameters.h"
#include "xstatus.h"

#ifndef XPAR_AXI_GPIO_RIS_CTL_DEVICE_ID
#error "Regenerate the key_ctrl BSP from the XSA containing axi_gpio_ris_ctl."
#endif

int gpio_ris_pack(enum gpio_ris_mode mode, u32 pins, u32 *command)
{
    if (command == NULL || (pins & ~GPIO_RIS_OUTPUT_MASK) != 0U)
        return GPIO_RIS_ERR_ARGUMENT;
    if (mode != GPIO_RIS_MODE_MONITOR && mode != GPIO_RIS_MODE_PS &&
        mode != GPIO_RIS_MODE_AUTO)
        return GPIO_RIS_ERR_ARGUMENT;

    *command = ((u32)mode << GPIO_RIS_MODE_SHIFT);
    if (mode == GPIO_RIS_MODE_PS)
        *command |= pins;
    return GPIO_RIS_OK;
}

int gpio_ris_write(gpio_ris_device *dev, enum gpio_ris_mode mode, u32 pins)
{
    u32 command;
    int status;

    if (dev == NULL)
        return GPIO_RIS_ERR_ARGUMENT;
    if (!dev->ready)
        return GPIO_RIS_ERR_NOT_READY;
    status = gpio_ris_pack(mode, pins, &command);
    if (status != GPIO_RIS_OK)
        return status;

    /* Write the entire mode/payload atomically. DiscreteSet/Clear would
     * require reading DATA, which is not an output-status feedback path.
     */
    XGpio_DiscreteWrite(&dev->gpio, GPIO_RIS_CHANNEL, command);
    dev->last_command = command;
    if (mode == GPIO_RIS_MODE_PS)
        dev->ps_values = pins;
    return GPIO_RIS_OK;
}

int gpio_ris_init(gpio_ris_device *dev)
{
    XGpio_Config *config;

    if (dev == NULL)
        return GPIO_RIS_ERR_ARGUMENT;
    memset(dev, 0, sizeof(*dev));
    config = XGpio_LookupConfig(XPAR_AXI_GPIO_RIS_CTL_DEVICE_ID);
    if (config == NULL || config->IsDual != 0 ||
        config->BaseAddress != XPAR_AXI_GPIO_RIS_CTL_BASEADDR)
        return GPIO_RIS_ERR_CONFIG;
    if (XGpio_CfgInitialize(&dev->gpio, config, config->BaseAddress)
        != XST_SUCCESS)
        return GPIO_RIS_ERR_CONFIG;

    XGpio_SetDataDirection(&dev->gpio, GPIO_RIS_CHANNEL, 0U);
    dev->ready = 1U;
    return gpio_ris_write(dev, GPIO_RIS_MODE_MONITOR, 0U);
}

int gpio_ris_set_mode(gpio_ris_device *dev, enum gpio_ris_mode mode)
{
    if (dev == NULL)
        return GPIO_RIS_ERR_ARGUMENT;
    return gpio_ris_write(dev, mode, dev->ps_values);
}

int gpio_ris_set_outputs(gpio_ris_device *dev, u32 pins)
{
    return gpio_ris_write(dev, GPIO_RIS_MODE_PS, pins);
}

int gpio_ris_set_pin(gpio_ris_device *dev, unsigned row, unsigned column,
                     unsigned value)
{
    u32 mask;
    u32 pins;

    if (dev == NULL || row < 1U || row > 5U || column < 1U || column > 5U ||
        value > 1U)
        return GPIO_RIS_ERR_ARGUMENT;
    if (!dev->ready)
        return GPIO_RIS_ERR_NOT_READY;
    mask = 1U << ((row - 1U) * 5U + column - 1U);
    pins = value ? (dev->ps_values | mask) : (dev->ps_values & ~mask);
    return gpio_ris_set_outputs(dev, pins);
}

int gpio_ris_get_command(const gpio_ris_device *dev, u32 *command)
{
    if (dev == NULL || command == NULL)
        return GPIO_RIS_ERR_ARGUMENT;
    if (!dev->ready)
        return GPIO_RIS_ERR_NOT_READY;
    *command = dev->last_command;
    return GPIO_RIS_OK;
}

const char *gpio_ris_status_string(int status)
{
    switch (status) {
    case GPIO_RIS_OK: return "OK";
    case GPIO_RIS_ERR_ARGUMENT: return "invalid RIS mode, payload or pin";
    case GPIO_RIS_ERR_NOT_READY: return "RIS AXI GPIO not initialized";
    case GPIO_RIS_ERR_CONFIG: return "RIS AXI GPIO BSP configuration mismatch";
    default: return "unknown error";
    }
}
