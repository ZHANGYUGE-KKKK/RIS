#ifndef TEST_XTIME_H
#define TEST_XTIME_H
#include "xil_types.h"
typedef uint64_t XTime;
#define COUNTS_PER_SECOND 1000000U
void XTime_GetTime(XTime *time);
#endif
