/* DMA bus: 0..0x7fffffff (2GiB). CPU0 uses the banked GP0 window.
 * All window transactions must finish before changing its bank. IRQ handlers
 * must not access this window. Ethernet/code/stack remain in PS DDR. */
#include "mig_ddr.h"

#include <string.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "xil_mmu.h"
#include "xpseudo_asm.h"
#include "xreg_cortexa9.h"

#ifndef XPAR_AXI_GPIO_DDR_BANK_BASEADDR
#error "Regenerate the BSP from the full-2GiB XSA with axi_gpio_ddr_bank."
#endif

int mig_ddr_select_bank(u32 bank)
{
    if (bank > 1U) return MIG_DDR_ERR_ARGUMENT;
    dsb();
    Xil_Out32(XPAR_AXI_GPIO_DDR_BANK_BASEADDR, bank);
    dsb();
    if ((Xil_In32(XPAR_AXI_GPIO_DDR_BANK_BASEADDR) & 1U) != bank)
        return MIG_DDR_ERR_BANK;
    dsb(); isb();
    return MIG_DDR_OK;
}

#define MIG_DDR_SECTION_BYTES 0x100000U

int mig_ddr_init(mig_ddr_device *dev)
{
    if (dev == NULL)
        return MIG_DDR_ERR_ARGUMENT;
    memset(dev, 0, sizeof(*dev));
    dev->base = MIG_DDR_BUS_BASE;
    dev->high = MIG_DDR_BUS_HIGH;
    if (XPAR_AXI_GPIO_DDR_BANK_BASEADDR != 0x83000000U)
        return MIG_DDR_ERR_CONFIG;
    Xil_Out32(XPAR_AXI_GPIO_DDR_BANK_BASEADDR + 4U, 0U);
    if (mig_ddr_select_bank(0U) != MIG_DDR_OK)
        return MIG_DDR_ERR_BANK;
    dev->ready = 1U;
    return MIG_DDR_OK;
}

int mig_ddr_check_region(const mig_ddr_device *dev, UINTPTR address,
                         u32 bytes, u32 alignment)
{
    if (dev == NULL || bytes == 0U || alignment == 0U ||
        (alignment & (alignment - 1U)) != 0U)
        return MIG_DDR_ERR_ARGUMENT;
    if (!dev->ready)
        return MIG_DDR_ERR_NOT_READY;
    if (address < dev->base || address > dev->high ||
        (u64)bytes > (u64)dev->high - address + 1U)
        return MIG_DDR_ERR_RANGE;
    if ((address & (alignment - 1U)) != 0U ||
        (bytes & (alignment - 1U)) != 0U)
        return MIG_DDR_ERR_ALIGNMENT;
    return MIG_DDR_OK;
}

int mig_ddr_map_uncached(const mig_ddr_device *dev, UINTPTR address, u32 bytes)
{
    UINTPTR section, last;
    extern u32 MMUTable[4096];
    u32 *table = MMUTable;
    u32 saved_cpsr, changed = 0U;
    int status = mig_ddr_check_region(dev, address, bytes, MIG_DDR_ALIGNMENT);

    if (status != MIG_DDR_OK)
        return status;
    section = MIG_DDR_CPU_BASE;
    last = MIG_DDR_CPU_BASE + MIG_DDR_WINDOW_BYTES - MIG_DDR_SECTION_BYTES;
    /* Map the CPU aperture only, never logical DMA addresses over PS DDR.
     * Device attributes prevent speculative reads through a changing bank.
     * Batch TLB/cache maintenance once; PS DDR/GEM/registers are untouched. */
    saved_cpsr = mfcpsr();
    mtcpsr(saved_cpsr | 0x80U);
    for (;;) {
        u32 descriptor = (u32)section | DEVICE_MEMORY;
        if (table[section >> 20] != descriptor) {
            table[section >> 20] = descriptor;
            changed = 1U;
        }
        if (section == last)
            break;
        section += MIG_DDR_SECTION_BYTES;
    }
    if (changed) {
        Xil_DCacheFlush();
        mtcp(XREG_CP15_INVAL_UTLB_UNLOCKED, 0U);
        mtcp(XREG_CP15_INVAL_BRANCH_ARRAY, 0U);
        dsb(); isb();
    }
    mtcpsr(saved_cpsr);
    return MIG_DDR_OK;
}

int mig_ddr_prepare_rx(const mig_ddr_device *dev, UINTPTR address, u32 bytes)
{
    int status = mig_ddr_map_uncached(dev, address, bytes);

    if (status != MIG_DDR_OK)
        return status;
    /* The exclusive noncacheable window has no dirty/cache-resident
     * payload lines after map_uncached. Do not walk a GiB line by line. */
    dsb();
    return MIG_DDR_OK;
}

int mig_ddr_complete_rx(const mig_ddr_device *dev, UINTPTR address, u32 bytes)
{
    int status = mig_ddr_check_region(dev, address, bytes, MIG_DDR_ALIGNMENT);

    if (status != MIG_DDR_OK)
        return status;
    /* All payload accesses remain uncached; DMA completion precedes this
     * ownership barrier. In particular, never flush old CPU data over RX. */
    dsb();
    return MIG_DDR_OK;
}

int mig_ddr_window_pointer(const mig_ddr_device *dev, UINTPTR address,
                            u32 bytes, void **pointer)
{
    u32 offset = (u32)address & (MIG_DDR_WINDOW_BYTES - 1U);
    int status;
    if (!pointer) return MIG_DDR_ERR_ARGUMENT;
    *pointer = NULL;
    status = mig_ddr_check_region(dev, address, bytes, 4U);
    if (status != MIG_DDR_OK) return status;
    if (bytes > MIG_DDR_WINDOW_BYTES - offset) return MIG_DDR_ERR_RANGE;
    status = mig_ddr_select_bank((u32)address >> 30);
    if (status != MIG_DDR_OK) return status;
    *pointer = (void *)(UINTPTR)(MIG_DDR_CPU_BASE + offset);
    return MIG_DDR_OK;
}

int mig_ddr_read(const mig_ddr_device *dev, UINTPTR address, void *out, u32 bytes)
{
    unsigned char *destination = out;
    int status;
    if (!out) return MIG_DDR_ERR_ARGUMENT;
    status = mig_ddr_check_region(dev, address, bytes, 4U);
    if (status != MIG_DDR_OK) return status;
    status = mig_ddr_map_uncached(dev, MIG_DDR_BUS_BASE, MIG_DDR_ALIGNMENT);
    if (status != MIG_DDR_OK) return status;
    while (bytes) {
        u32 i, count = MIG_DDR_WINDOW_BYTES - ((u32)address & (MIG_DDR_WINDOW_BYTES - 1U));
        void *window;
        const volatile u32 *source;
        if (count > bytes) count = bytes;
        status = mig_ddr_window_pointer(dev, address, count, &window);
        if (status != MIG_DDR_OK) break;
        source = window;
        /* Explicit aligned reads are valid for Device memory. memcpy is only
         * used between the local word and the normal PS destination. */
        for (i = 0; i < count; i += 4U) {
            u32 word = source[i/4U];
            memcpy(destination+i, &word, sizeof(word));
        }
        dsb();
        address += count; destination += count; bytes -= count;
    }
    /* BD virtual addresses always refer to bank zero, including after errors. */
    if (mig_ddr_select_bank(0U) != MIG_DDR_OK) return MIG_DDR_ERR_BANK;
    return status;
}

const char *mig_ddr_status_string(int status)
{
    switch (status) {
    case MIG_DDR_OK: return "OK";
    case MIG_DDR_ERR_ARGUMENT: return "invalid argument";
    case MIG_DDR_ERR_NOT_READY: return "MIG memory range not initialized";
    case MIG_DDR_ERR_CONFIG: return "MIG DDR BSP address range mismatch";
    case MIG_DDR_ERR_RANGE: return "memory region outside MIG DDR";
    case MIG_DDR_ERR_ALIGNMENT: return "memory address/size alignment mismatch";
    case MIG_DDR_ERR_BANK: return "CPU DDR window bank readback mismatch";
    default: return "unknown error";
    }
}
