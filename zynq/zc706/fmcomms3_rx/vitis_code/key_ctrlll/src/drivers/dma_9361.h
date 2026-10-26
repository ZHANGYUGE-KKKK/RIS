#ifndef DMA_9361_H
#define DMA_9361_H

#include "xaxidma.h"
#include "gpio_9361.h"
#include "mig_ddr.h"
#include "dma_diag.h"

#ifdef __cplusplus
extern "C" {
#endif

#define DMA_9361_PACKET_SAMPLES  4096U
#define DMA_9361_SAMPLE_BYTES    8U
#define DMA_9361_PACKET_BYTES    (DMA_9361_PACKET_SAMPLES * DMA_9361_SAMPLE_BYTES)
#define DMA_9361_DEFAULT_BD_BASE 0x00000000U
#define DMA_9361_DEFAULT_BUFFER  0x00400000U
#define DMA_9361_DEFAULT_PACKETS 256U /* 8 MiB; 1,048,576 dual-channel tuples. */

enum dma_9361_status {
    DMA_9361_OK = 0,
    DMA_9361_PENDING = 1,
    DMA_9361_ERR_ARGUMENT = -1,
    DMA_9361_ERR_NOT_READY = -2,
    DMA_9361_ERR_CONFIG = -3,
    DMA_9361_ERR_MEMORY = -4,
    DMA_9361_ERR_STATE = -5,
    DMA_9361_ERR_RING = -6,
    DMA_9361_ERR_DMA = -7,
    DMA_9361_ERR_CAPTURE = -8,
    DMA_9361_ERR_PACKET = -9,
    DMA_9361_ERR_TIMEOUT = -10,
    DMA_9361_ERR_RESET_REQUIRED = -11,
    DMA_9361_ERR_ABORTED = -12
};

enum dma_9361_state {
    DMA_9361_IDLE = 0,
    DMA_9361_PREPARED,
    DMA_9361_RUNNING,
    DMA_9361_COMPLETE,
    DMA_9361_FAILED
};

/* Little-endian 64-bit AXIS tuple, each signed 12-bit component sign-extended
 * to 16 bits. No gain correction, frequency change or sample decimation.
 */
typedef struct {
    s16 i1;
    s16 q1;
    s16 i2;
    s16 q2;
} dma_9361_sample;

typedef struct {
    XAxiDma dma;
    gpio_9361_device *capture;
    mig_ddr_device memory;
    XAxiDma_Bd *bd_set;
    UINTPTR bd_base;
    UINTPTR buffer_base;
    u32 bd_bytes;
    u32 buffer_bytes;
    u32 packet_count;
    u32 completed_packets;
    u32 received_bytes;
    u32 last_dma_status;
    u32 last_bd_status;
    u32 last_capture_status;
    dma_diag_record debug;
    int last_error;
    enum dma_9361_state state;
    u8 ready;
    u8 started;
    u8 needs_pl_reset;
} dma_9361_device;

/* Polling SG S2MM only, 64-bit stream, 32-bit DMA address, no cyclic mode.
 * init resets DMA only; it does not access DDR, initialize the RF interface
 * or reset the receiver/external AXIS FIFO. All interrupts are disabled.
 * The caller exclusively owns this DMA, GPIO, and supplied memory sections.
 */
int dma_9361_init(dma_9361_device *dev, gpio_9361_device *capture);
/* One complete 32 KiB AXIS packet per 64-byte-aligned descriptor. Both the
 * descriptor ring and contiguous payload must fit MIG and must not overlap.
 * This reserves/initializes DDR; MIG calibration must already be complete.
 */
int dma_9361_prepare(dma_9361_device *dev, UINTPTR bd_base,
                     UINTPTR buffer_base, u32 packet_count);
/* Submit all BDs, start S2MM, then assert ARM after RX ready/FRAME locked. */
int dma_9361_start(dma_9361_device *dev);
/* pending=1, complete=0, failures<0. Checks DMA/BD errors, SOF/EOF, packet
 * lengths, and all capture errors. No descriptors are recycled to hardware.
 */
int dma_9361_poll(dma_9361_device *dev);
int dma_9361_wait(dma_9361_device *dev, u32 timeout_us);
/* Reset DMA and deassert the ARM command. Source/FIFOs still require PL
 * reset if ARM was issued. Partial buffers are invalid after any failure.
 */
int dma_9361_abort(dma_9361_device *dev);
/* Stop/reset DMA after completion, preserving DDR and the diagnostic record.
 * This does not clear the capture FIFOs or permit another ARM. */
int dma_9361_quiesce(dma_9361_device *dev);
/* Last transfer snapshot survives init/rearm; no live PL reads or resets. */
const dma_diag_record *dma_9361_last_debug(void);
/* Data becomes CPU-owned only after a successful poll/wait. Another capture
 * requires PL/system reset to flush both FIFOs and clear latched ARM/errors.
 * Source continues sampling after this finite window and may then overflow.
 */
int dma_9361_get_samples(const dma_9361_device *dev,
                         const dma_9361_sample **samples, u32 *sample_count);
/* Optional cooperative transport pump. Never call capture/DMA APIs here. */
void dma_9361_set_service_hook(void (*service)(void));
const char *dma_9361_status_string(int status);

#ifdef __cplusplus
}
#endif

#endif
