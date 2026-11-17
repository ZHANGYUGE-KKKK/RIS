#ifndef MIG_DDR_H
#define MIG_DDR_H

#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MIG_DDR_ALIGNMENT 32U
#define MIG_DDR_BUS_BASE 0U
#define MIG_DDR_BUS_HIGH 0x7FFFFFFFU
#define MIG_DDR_CPU_BASE 0x40000000U
#define MIG_DDR_WINDOW_BYTES 0x40000000U

enum mig_ddr_status {
    MIG_DDR_OK = 0,
    MIG_DDR_ERR_ARGUMENT = -1,
    MIG_DDR_ERR_NOT_READY = -2,
    MIG_DDR_ERR_CONFIG = -3,
    MIG_DDR_ERR_RANGE = -4,
    MIG_DDR_ERR_ALIGNMENT = -5,
    MIG_DDR_ERR_BANK = -6
};

typedef struct {
    UINTPTR base;
    UINTPTR high;
    u8 ready;
} mig_ddr_device;

/* Addresses in this API are DMA bus addresses 0..0x7fffffff. They must never
 * be dereferenced by CPU0. init selects bank zero but does not calibrate MIG.
 * Code/stack/heap remain in PS DDR. Only CPU0 owns the banked GP0 window. */
int mig_ddr_init(mig_ddr_device *dev);
int mig_ddr_check_region(const mig_ddr_device *dev, UINTPTR address,
                         u32 bytes, u32 alignment);
/* Map only 0x40000000..0x7fffffff as noncacheable Device sections. This does
 * not change MMU attributes of PS DDR or the AXI control register aperture. */
int mig_ddr_map_uncached(const mig_ddr_device *dev, UINTPTR address, u32 bytes);
/* RX ownership: prepare before DMA; do not access until complete after DMA.
 * Both address and size must be multiples of 32. No cache flush after RX.
 */
int mig_ddr_prepare_rx(const mig_ddr_device *dev, UINTPTR address, u32 bytes);
int mig_ddr_complete_rx(const mig_ddr_device *dev, UINTPTR address, u32 bytes);
/* Drain CPU window accesses before changing bank. IRQ handlers may not use it. */
int mig_ddr_select_bank(u32 bank);
/* Borrow a pointer within one bank only. It expires on the next bank change.
 * The caller must restore bank zero before inspecting SG descriptors. */
int mig_ddr_window_pointer(const mig_ddr_device *dev, UINTPTR address,
                            u32 bytes, void **pointer);
/* Copy even across the 1GiB boundary; all bus reads are aligned 32-bit.
 * Restores bank zero before returning. out is an ordinary PS memory buffer. */
int mig_ddr_read(const mig_ddr_device *dev, UINTPTR address, void *out, u32 bytes);
const char *mig_ddr_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
