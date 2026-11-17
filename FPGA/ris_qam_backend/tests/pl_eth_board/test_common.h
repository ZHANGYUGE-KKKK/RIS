#ifndef TEST_COMMON_H
#define TEST_COMMON_H
#include <stdint.h>
#include <stddef.h>
typedef uint64_t XTime;
#define COUNTS_PER_SECOND 1000000ULL
void XTime_GetTime(XTime *now);
typedef uint8_t u8; typedef uint32_t u32; typedef uintptr_t UINTPTR;
#define XST_SUCCESS 0
#define XPAR_XIICPS_0_DEVICE_ID 0
#define XPAR_XGPIOPS_0_DEVICE_ID 0
typedef struct { UINTPTR BaseAddress; u32 InputClockHz; } XIicPs_Config;
typedef struct { XIicPs_Config Config; } XIicPs;
typedef struct { UINTPTR BaseAddr; } XGpioPs_Config;
typedef struct { int initialized; } XGpioPs;
XIicPs_Config *XIicPs_LookupConfig(u32);
int XIicPs_CfgInitialize(XIicPs *,XIicPs_Config *,UINTPTR);
int XIicPs_SetSClk(XIicPs *,u32);
XGpioPs_Config *XGpioPs_LookupConfig(u32);
int XGpioPs_CfgInitialize(XGpioPs *,XGpioPs_Config *,UINTPTR);
void XGpioPs_WritePin(XGpioPs *,u32,u32);
void XGpioPs_SetDirectionPin(XGpioPs *,u32,u32);
void XGpioPs_SetOutputEnablePin(XGpioPs *,u32,u32);
u32 mock_read(UINTPTR,u32);
void mock_write(UINTPTR,u32,u32);
#define usleep test_usleep
void usleep(unsigned);
int xil_printf(const char *,...);
#define XIicPs_ReadReg mock_read
#define XIicPs_WriteReg mock_write
#define XIicPs_DisableAllInterrupts(base) mock_write(base,XIICPS_IDR_OFFSET,XIICPS_IXR_ALL_INTR_MASK)
#define XIICPS_CR_OFFSET 0x00U
#define XIICPS_SR_OFFSET 0x04U
#define XIICPS_ADDR_OFFSET 0x08U
#define XIICPS_DATA_OFFSET 0x0CU
#define XIICPS_ISR_OFFSET 0x10U
#define XIICPS_TRANS_SIZE_OFFSET 0x14U
#define XIICPS_IDR_OFFSET 0x28U
#define XIICPS_CR_DIV_A_MASK 0xC000U
#define XIICPS_CR_DIV_B_MASK 0x3F00U
#define XIICPS_CR_CLR_FIFO_MASK 0x40U
#define XIICPS_CR_ACKEN_MASK 0x08U
#define XIICPS_CR_NEA_MASK 0x04U
#define XIICPS_CR_MS_MASK 0x02U
#define XIICPS_CR_RD_WR_MASK 0x01U
#define XIICPS_SR_BA_MASK 0x100U
#define XIICPS_SR_RXDV_MASK 0x20U
#define XIICPS_IXR_ARB_LOST_MASK 0x200U
#define XIICPS_IXR_RX_UNF_MASK 0x80U
#define XIICPS_IXR_TX_OVR_MASK 0x40U
#define XIICPS_IXR_RX_OVR_MASK 0x20U
#define XIICPS_IXR_TO_MASK 0x08U
#define XIICPS_IXR_NACK_MASK 0x04U
#define XIICPS_IXR_COMP_MASK 0x01U
#define XIICPS_IXR_ALL_INTR_MASK 0x2FFU
#endif
