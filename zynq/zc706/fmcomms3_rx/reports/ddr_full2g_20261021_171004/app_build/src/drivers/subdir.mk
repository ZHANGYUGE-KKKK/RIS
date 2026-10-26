################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/drivers/ad9361.c \
../src/drivers/cdcm6208.c \
../src/drivers/dma_9361.c \
../src/drivers/gpio_9361.c \
../src/drivers/gpio_ris.c \
../src/drivers/mig_ddr.c \
../src/drivers/rx_9361.c 

OBJS += \
./src/drivers/ad9361.o \
./src/drivers/cdcm6208.o \
./src/drivers/dma_9361.o \
./src/drivers/gpio_9361.o \
./src/drivers/gpio_ris.o \
./src/drivers/mig_ddr.o \
./src/drivers/rx_9361.o 

C_DEPS += \
./src/drivers/ad9361.d \
./src/drivers/cdcm6208.d \
./src/drivers/dma_9361.d \
./src/drivers/gpio_9361.d \
./src/drivers/gpio_ris.d \
./src/drivers/mig_ddr.d \
./src/drivers/rx_9361.d 


# Each subdirectory must supply rules for building sources it contributes
src/drivers/%.o: ../src/drivers/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: ARM v7 gcc compiler'
	arm-none-eabi-gcc -Wall -O0 -g3 -c -fmessage-length=0 -MT"$@" -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -I/home/yyz/work/RIS/zynq/zc706/fmcomms3_rx/reports/ddr_full2g_20261021_171004/network_bsp/ps7_cortexa9_0/include -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


