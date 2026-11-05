#ifndef TEST_XIL_IO_H
#define TEST_XIL_IO_H
#include "xil_types.h"
void fake_out32(UINTPTR address, u32 value);
u32 fake_in32(UINTPTR address);
#define Xil_Out32 fake_out32
#define Xil_In32 fake_in32
#endif
