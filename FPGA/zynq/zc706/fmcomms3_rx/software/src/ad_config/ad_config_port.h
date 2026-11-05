#ifndef RFMC6000_AD_CONFIG_PORT_H
#define RFMC6000_AD_CONFIG_PORT_H

#include "ad_config.h"

int ad_config_port_bind(ad9361_device *transport);
int ad_config_port_error(void);
void ad_config_port_calibration(u32 reg, u32 mask, s32 value);

#endif
