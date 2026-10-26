/* Physical DIMM: 2GiB, 2Rx8, DDR3-1333. PS GP0 and DMA SG/S2MM
 * retain the existing 1GiB aperture for the IQ storage fault comparison. */
#include "mig_ddr.h"

#include <string.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xil_mmu.h"
#include "xpseudo_asm.h"
#include "xreg_cortexa9.h"

#ifndef XPAR_MIG_7SERIES_0_BASEADDR
#error "Regenerate the key_ctrl BSP from the XSA containing mig_7series_0."
#endif

#define MIG_DDR_SECTION_BYTES 0x100000U

int mig_ddr_init(mig_ddr_device *dev)
{
    if (dev == NULL)
        return MIG_DDR_ERR_ARGUMENT;
    memset(dev, 0, sizeof(*dev));
    dev->base = XPAR_MIG_7SERIES_0_BASEADDR;
    dev->high = XPAR_MIG_7SERIES_0_HIGHADDR;
    if (dev->base != 0x40000000U || dev->high != 0x7FFFFFFFU)
        return MIG_DDR_ERR_CONFIG;
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
    section = address & ~(UINTPTR)(MIG_DDR_SECTION_BYTES - 1U);
    last = (address + bytes - 1U) & ~(UINTPTR)(MIG_DDR_SECTION_BYTES - 1U);
    /* Same section descriptors/barriers as BSP Xil_SetTlbAttributes, batched
     * so mapping 1 GiB does not flush the entire cache 1024 times. CPU0 alone
     * owns these mappings; no PL-memory access/DMA is allowed during prepare.
     * PS Ethernet mappings are untouched. */
    saved_cpsr = mfcpsr();
    mtcpsr(saved_cpsr | 0x80U);
    for (;;) {
        u32 descriptor = (u32)section | NORM_NONCACHE;
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
    /* The exclusive normal-noncacheable mapping has no dirty/cache-resident
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

const char *mig_ddr_status_string(int status)
{
    switch (status) {
    case MIG_DDR_OK: return "OK";
    case MIG_DDR_ERR_ARGUMENT: return "invalid argument";
    case MIG_DDR_ERR_NOT_READY: return "MIG memory range not initialized";
    case MIG_DDR_ERR_CONFIG: return "MIG DDR BSP address range mismatch";
    case MIG_DDR_ERR_RANGE: return "memory region outside MIG DDR";
    case MIG_DDR_ERR_ALIGNMENT: return "memory address/size alignment mismatch";
    default: return "unknown error";
    }
}
