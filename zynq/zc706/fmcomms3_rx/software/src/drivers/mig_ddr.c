/* PS GP0 and DMA SG/S2MM share MIG's 1 GiB PL DDR memory aperture. */
#include "mig_ddr.h"

#include <string.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xil_mmu.h"

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
    int status = mig_ddr_check_region(dev, address, bytes, MIG_DDR_ALIGNMENT);

    if (status != MIG_DDR_OK)
        return status;
    section = address & ~(UINTPTR)(MIG_DDR_SECTION_BYTES - 1U);
    last = (address + bytes - 1U) & ~(UINTPTR)(MIG_DDR_SECTION_BYTES - 1U);
    /* Xil_SetTlbAttributes flushes caches and invalidates the TLB. The old
     * default mapping describes this aperture as strongly ordered PL I/O.
     */
    for (;;) {
        Xil_SetTlbAttributes((INTPTR)section, NORM_NONCACHE);
        if (section == last)
            break;
        section += MIG_DDR_SECTION_BYTES;
    }
    return MIG_DDR_OK;
}

int mig_ddr_prepare_rx(const mig_ddr_device *dev, UINTPTR address, u32 bytes)
{
    int status = mig_ddr_map_uncached(dev, address, bytes);

    if (status != MIG_DDR_OK)
        return status;
    Xil_DCacheFlushRange(address, bytes);
    Xil_DCacheInvalidateRange(address, bytes);
    return MIG_DDR_OK;
}

int mig_ddr_complete_rx(const mig_ddr_device *dev, UINTPTR address, u32 bytes)
{
    int status = mig_ddr_check_region(dev, address, bytes, MIG_DDR_ALIGNMENT);

    if (status != MIG_DDR_OK)
        return status;
    Xil_DCacheInvalidateRange(address, bytes);
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
