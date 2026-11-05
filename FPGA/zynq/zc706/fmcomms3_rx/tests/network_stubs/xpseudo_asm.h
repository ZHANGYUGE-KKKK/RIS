#include "xil_types.h"
extern u32 fake_cpsr;
void fake_barrier(void);
void fake_mtcp(unsigned reg, unsigned value);
#define mfcpsr() (fake_cpsr)
#define mtcpsr(value) (fake_cpsr=(value))
#define mtcp(reg,value) fake_mtcp((reg),(value))
#define dsb() fake_barrier()
#define isb() fake_barrier()
