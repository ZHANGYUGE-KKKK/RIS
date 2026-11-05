/* The fixed 1GiB CPU window crosses ASan's host shadow. This target uses
 * UBSan; the protocol/capture-state tests still run with ASan + UBSan. */
#include "mig_ddr.h"
#include "xil_mmu.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

u32 MMUTable[4096], fake_cpsr;
static unsigned flushes, invalidations, barriers, bank, switches, bad_readback;
static int backing;
void Xil_DCacheFlush(void) { ++flushes; }
void fake_barrier(void) { ++barriers; }
void fake_mtcp(unsigned reg, unsigned value)
{ assert((reg==1 || reg==2) && value==0); ++invalidations; }
void fake_out32(UINTPTR address, u32 value)
{
    if (address==0x83000004U) { assert(value==0); return; }
    assert(address==0x83000000U && value<=1);
    assert(mmap((void *)(UINTPTR)MIG_DDR_CPU_BASE, MIG_DDR_WINDOW_BYTES,
                PROT_READ|PROT_WRITE, MAP_SHARED|MAP_FIXED, backing,
                (off_t)value*MIG_DDR_WINDOW_BYTES)==(void *)(UINTPTR)MIG_DDR_CPU_BASE);
    bank=value; ++switches;
}
u32 fake_in32(UINTPTR address)
{ assert(address==0x83000000U); return bank ^ bad_readback; }

int main(void)
{
    mig_ddr_device memory;
    unsigned i;
    unsigned char tagged[64], out[66];
    void *pointer;
    backing=memfd_create("two-independent-ddr-ranks",MFD_CLOEXEC);
    assert(backing>=0 && !ftruncate(backing,0x80000000ULL));
    for(i=0;i<4096;++i) MMUTable[i]=(i<<20)|0x11de2U;
    fake_cpsr=0x13;
    assert(!mig_ddr_init(&memory) && bank==0);
    assert(memory.base==0 && memory.high==0x7fffffffU);
    assert(mig_ddr_prepare_rx(&memory,0x7fffffe0,64)==MIG_DDR_ERR_RANGE);
    assert(mig_ddr_prepare_rx(&memory,1,32)==MIG_DDR_ERR_ALIGNMENT);
    assert(!mig_ddr_prepare_rx(&memory,0,0x80000000U));
    assert(flushes==1 && invalidations==2 && fake_cpsr==0x13);
    for(i=0;i<4096;++i) {
        u32 expected=(i<<20)|((i>=1024 && i<2048)?DEVICE_MEMORY:0x11de2U);
        assert(MMUTable[i]==expected);
    }
    fake_cpsr=0x93;
    assert(!mig_ddr_prepare_rx(&memory,0x00400000,0x7fc00000));
    assert(!mig_ddr_complete_rx(&memory,0x00400000,0x7fc00000));
    assert(flushes==1 && invalidations==2 && fake_cpsr==0x93);
    for(i=0;i<sizeof(tagged);++i) tagged[i]=(unsigned char)(i*37U+11U);
    assert(pwrite(backing,tagged,32,0x3ffffff0)==32);
    assert(!mig_ddr_read(&memory,0x3ffffff0,out+1,32));
    assert(!memcmp(out+1,tagged,32) && bank==0);
    assert(pwrite(backing,tagged+32,32,0x7fffffe0)==32);
    assert(!mig_ddr_read(&memory,0x7fffffe0,out,32));
    assert(!memcmp(out,tagged+32,32) && bank==0);
    assert(!mig_ddr_read(&memory,0x40000008,out,8));
    assert(!memcmp(out,tagged+24,8) && bank==0);
    assert(mig_ddr_window_pointer(&memory,0x3ffffff0,32,&pointer)==MIG_DDR_ERR_RANGE);
    assert(!mig_ddr_window_pointer(&memory,0x40000000,32,&pointer));
    assert(pointer==(void *)(UINTPTR)MIG_DDR_CPU_BASE && bank==1);
    assert(!mig_ddr_select_bank(0));
    assert(mig_ddr_read(&memory,0x80000000U,out,4)==MIG_DDR_ERR_RANGE);
    assert(mig_ddr_read(&memory,0,out,3)==MIG_DDR_ERR_ALIGNMENT);
    bad_readback=1;
    assert(mig_ddr_read(&memory,0x40000000,out,32)==MIG_DDR_ERR_BANK);
    assert(bank==0);
    bad_readback=0;
    assert(barriers>10 && switches>6 && flushes==1 && fake_cpsr==0x93);
    assert(!munmap((void *)(UINTPTR)MIG_DDR_CPU_BASE,MIG_DDR_WINDOW_BYTES));
    close(backing);
    puts("PASS: full-2GiB range, independent ranks, cross-bank copies, last byte, bank-zero restoration, MMU/PS isolation and IRQ preservation");
    return 0;
}
