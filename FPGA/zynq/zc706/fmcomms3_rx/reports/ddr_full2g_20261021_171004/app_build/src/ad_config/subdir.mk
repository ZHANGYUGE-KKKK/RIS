################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/ad_config/ad9361.c \
../src/ad_config/ad9361_api.c \
../src/ad_config/ad_config.c \
../src/ad_config/platform.c \
../src/ad_config/util.c 

OBJS += \
./src/ad_config/ad9361.o \
./src/ad_config/ad9361_api.o \
./src/ad_config/ad_config.o \
./src/ad_config/platform.o \
./src/ad_config/util.o 

C_DEPS += \
./src/ad_config/ad9361.d \
./src/ad_config/ad9361_api.d \
./src/ad_config/ad_config.d \
./src/ad_config/platform.d \
./src/ad_config/util.d 


# Each subdirectory must supply rules for building sources it contributes
src/ad_config/%.o: ../src/ad_config/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: ARM v7 gcc compiler'
	arm-none-eabi-gcc -Wall -O0 -g3 -c -fmessage-length=0 -MT"$@" -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -I/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/network_bsp/ps7_cortexa9_0/include -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


