#ifndef RIS_CONTROLLER_H
#define RIS_CONTROLLER_H

#include "xil_types.h"
#include "ris_controller_regs.h"

#define RIS_BASE_ADDRESS 0x41200000u
#define RIS_DEVICE_ID 0x52495332u
#define RIS_STATUS_INITIALIZED (1u << 6)
#define RIS_STATUS_OUTPUT_ENABLED (1u << 7)

/* One software owner; all commands are synchronous with a bounded wait. */
typedef struct {
    UINTPTR base;
    u32 next_id;
    u32 last_result;
    int fast_supported;
    int mt_supported;
    u32 mt_expected, mt_loaded, mt_checksum, mt_last_level;
} ris_controller;

enum {
    RIS_OK = 0,
    RIS_BAD_DEVICE = -1,
    RIS_TIMEOUT = -2,
    RIS_NOT_ACCEPTED = -3,
    RIS_COMMAND_FAILED = -4,
    RIS_IMAGE_MISMATCH = -5,
    RIS_HARDWARE_ERROR = -6
};

u32 ris_read(const ris_controller *dev, u32 offset);
u64 ris_frame_count(const ris_controller *dev);
int ris_initialize(ris_controller *dev, UINTPTR base);
int ris_set_all(ris_controller *dev, int high);
int ris_apply_pattern(ris_controller *dev, const u8 image[50], u64 mask);
int ris_output_enable(ris_controller *dev, int enable);
int ris_fast_start(ris_controller *dev, u32 mhz);
int ris_fast_start_ticks(ris_controller *dev, u32 half_ticks);
int ris_fast_start_hz(ris_controller *dev, u32 hz);
u32 ris_fast_ticks(const ris_controller *dev);
int ris_fast_stop(ris_controller *dev);
u32 ris_fast_mhz(const ris_controller *dev);
int ris_mt_begin(ris_controller *dev, u32 count, u32 loop_start, u32 period, u32 delay);
int ris_mt_segment(ris_controller *dev, u32 index, u32 level, u32 ticks);
int ris_mt_start(ris_controller *dev, u32 loop, u32 checksum);
void ris_mt_cancel_upload(ris_controller *dev);

#endif
