#ifndef MIG_DDR_H
#define MIG_DDR_H

#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define MIG_DDR_ALIGNMENT 32U /* MIG AXI width and Cortex-A9 cache-line size. */

enum mig_ddr_status {
    MIG_DDR_OK = 0,
    MIG_DDR_ERR_ARGUMENT = -1,
    MIG_DDR_ERR_NOT_READY = -2,
    MIG_DDR_ERR_CONFIG = -3,
    MIG_DDR_ERR_RANGE = -4,
    MIG_DDR_ERR_ALIGNMENT = -5
};

typedef struct {
    UINTPTR base;
    UINTPTR high;
    u8 ready;
} mig_ddr_device;

/* MIG has a memory aperture, not a software control-register interface.
 * init checks the BSP range (currently 0x40000000..0x7FFFFFFF); it does not
 * test or calibrate DDR. MIG clocks/reset/calibration must already be valid.
 * The application's code/stack/heap stay in PS DDR.
 */
int mig_ddr_init(mig_ddr_device *dev);
int mig_ddr_check_region(const mig_ddr_device *dev, UINTPTR address,
                         u32 bytes, u32 alignment);
/* Cortex-A9 uses 1 MiB MMU sections. The caller must exclusively own all
 * sections touched by this API and call it before handing memory to DMA.
 * Map as normal non-cacheable memory; physical and CPU addresses are equal.
 */
int mig_ddr_map_uncached(const mig_ddr_device *dev, UINTPTR address, u32 bytes);
/* RX ownership: prepare before DMA; do not access until complete after DMA.
 * Both address and size must be multiples of 32. No cache flush after RX.
 */
int mig_ddr_prepare_rx(const mig_ddr_device *dev, UINTPTR address, u32 bytes);
int mig_ddr_complete_rx(const mig_ddr_device *dev, UINTPTR address, u32 bytes);
const char *mig_ddr_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
