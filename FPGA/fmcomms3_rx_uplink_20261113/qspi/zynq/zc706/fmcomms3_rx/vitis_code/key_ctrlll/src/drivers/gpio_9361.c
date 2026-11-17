/* PS GP1 -> axi_gpio_9361 -> receiver ARM and status. */
#include "gpio_9361.h"

#include <string.h>
#include "xparameters.h"
#include "xstatus.h"
#include "xtime_l.h"

#ifndef XPAR_AXI_GPIO_9361_DEVICE_ID
#error "Regenerate the key_ctrl BSP from the XSA containing axi_gpio_9361."
#endif

#define GPIO_9361_POLL_LIMIT 1000000U

int gpio_9361_init(gpio_9361_device *dev)
{
    XGpio_Config *config;

    if (dev == NULL)
        return GPIO_9361_ERR_ARGUMENT;
    memset(dev, 0, sizeof(*dev));
    config = XGpio_LookupConfig(XPAR_AXI_GPIO_9361_DEVICE_ID);
    if (config == NULL || !config->IsDual ||
        config->BaseAddress != XPAR_AXI_GPIO_9361_BASEADDR)
        return GPIO_9361_ERR_CONFIG;
    if (XGpio_CfgInitialize(&dev->gpio, config, config->BaseAddress)
        != XST_SUCCESS)
        return GPIO_9361_ERR_CONFIG;

    XGpio_DiscreteWrite(&dev->gpio, GPIO_9361_ARM_CHANNEL, 0U);
    XGpio_SetDataDirection(&dev->gpio, GPIO_9361_ARM_CHANNEL, 0U);
    XGpio_SetDataDirection(&dev->gpio, GPIO_9361_STATUS_CHANNEL, 0xFFFFFFFFU);
    dev->ready = 1U;
    return gpio_9361_get_status(dev, &dev->last_status);
}

int gpio_9361_get_status(gpio_9361_device *dev, u32 *status)
{
    if (dev == NULL || status == NULL)
        return GPIO_9361_ERR_ARGUMENT;
    if (!dev->ready)
        return GPIO_9361_ERR_NOT_READY;
    dev->last_status = XGpio_DiscreteRead(&dev->gpio,
                         GPIO_9361_STATUS_CHANNEL) & GPIO_9361_STATUS_MASK;
    *status = dev->last_status;
    return GPIO_9361_OK;
}

int gpio_9361_check_ready(gpio_9361_device *dev)
{
    u32 flags;
    int status = gpio_9361_get_status(dev, &flags);

    if (status != GPIO_9361_OK)
        return status;
    if (flags & GPIO_9361_ERROR_MASK)
        return GPIO_9361_ERR_CAPTURE;
    if (dev->armed || (flags & GPIO_9361_ACTIVE_MASK))
        return GPIO_9361_ERR_RESET_REQUIRED;
    if ((flags & (GPIO_9361_READY_MASK | GPIO_9361_FRAME_LOCKED_MASK)) !=
        (GPIO_9361_READY_MASK | GPIO_9361_FRAME_LOCKED_MASK))
        return GPIO_9361_ERR_NOT_READY;
    return GPIO_9361_OK;
}

int gpio_9361_wait_ready(gpio_9361_device *dev, u32 timeout_us)
{
    XTime start, now;
    XTime timeout;
    u32 polls;
    int status;

    if (dev == NULL || timeout_us == 0U)
        return GPIO_9361_ERR_ARGUMENT;
    timeout = (XTime)COUNTS_PER_SECOND * timeout_us / 1000000U;
    XTime_GetTime(&start);
    for (polls = 0U; polls < GPIO_9361_POLL_LIMIT; ++polls) {
        status = gpio_9361_check_ready(dev);
        if (status != GPIO_9361_ERR_NOT_READY || !dev->ready)
            return status;
        XTime_GetTime(&now);
        if (now - start >= timeout)
            break;
    }
    return GPIO_9361_ERR_TIMEOUT;
}

int gpio_9361_arm(gpio_9361_device *dev)
{
    int status = gpio_9361_check_ready(dev);

    if (status != GPIO_9361_OK)
        return status;
    XGpio_DiscreteWrite(&dev->gpio, GPIO_9361_ARM_CHANNEL,
                       GPIO_9361_ARM_MASK);
    dev->armed = 1U;
    return GPIO_9361_OK;
}

int gpio_9361_release_arm(gpio_9361_device *dev)
{
    if (dev == NULL)
        return GPIO_9361_ERR_ARGUMENT;
    if (!dev->ready)
        return GPIO_9361_ERR_NOT_READY;
    XGpio_DiscreteWrite(&dev->gpio, GPIO_9361_ARM_CHANNEL, 0U);
    return GPIO_9361_OK;
}

const char *gpio_9361_status_string(int status)
{
    switch (status) {
    case GPIO_9361_OK: return "OK";
    case GPIO_9361_ERR_ARGUMENT: return "invalid argument";
    case GPIO_9361_ERR_NOT_READY: return "receiver/FIFO/FRAME not ready";
    case GPIO_9361_ERR_CONFIG: return "capture AXI GPIO BSP configuration mismatch";
    case GPIO_9361_ERR_CAPTURE: return "overflow, FRAME or IDELAY error; reset PL";
    case GPIO_9361_ERR_RESET_REQUIRED: return "receiver already armed; reset PL";
    case GPIO_9361_ERR_TIMEOUT: return "receiver readiness timed out";
    default: return "unknown error";
    }
}
