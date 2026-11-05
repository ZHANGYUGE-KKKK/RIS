#ifndef CAPTURE_STORE_H
#define CAPTURE_STORE_H
#include "dma_9361.h"
#include "capture_format.h"
#include "xtime_l.h"
#include "capture_debug.h"
#define CAPTURE_RF_REGS 14U
enum capture_store_state { CAP_STORE_UNAVAILABLE, CAP_STORE_EMPTY,
    CAP_STORE_CAPTURING, CAP_STORE_READY, CAP_STORE_FAILED };
typedef struct {
    enum capture_store_state state;
    capture_layout layout;
    char id[17];
    u8 rf_before[CAPTURE_RF_REGS], rf_after[CAPTURE_RF_REGS];
    u32 completed_packets, received_bytes, dma_status, bd_status;
    u32 capture_status, tail_status, elapsed_us;
    int result, reset_verified;
    XTime start;
    dma_diag_record dma_debug;
    capture_debug_report debug;
    u32 debug_elapsed_us, read_ops, read_bad[4], first_read_bad_offset, first_read_bad_raw;
} capture_store_record;
extern capture_store_record capture_store;
void capture_store_init(dma_9361_device *dma, gpio_9361_device *gpio,
                        int (*rearm)(void), int (*read_rf)(u8 *registers));
int capture_store_begin(u32 bytes);
void capture_store_poll(void);
void capture_store_abort(void);
int capture_store_release(const char *id);
int capture_store_read(const char *id, u32 offset, u32 bytes, void *destination);
int capture_store_keys_blocked(void);
int capture_store_urgent(void);
const char *capture_store_state_name(void);
/* Stable metadata/config readback. Output is a complete JSON line. */
int capture_store_json(char *buffer, unsigned capacity);
void capture_store_debug_print(void);
int capture_store_debug_json(char *buffer, unsigned capacity);
#endif
