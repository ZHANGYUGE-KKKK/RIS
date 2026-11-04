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
    int qam_supported, qam_uploading, qam_counts_set;
    u32 qam_ticks, qam_k, qam_slots, qam_loop;
    u32 qam_expected[3], qam_loaded[4];
    u32 qam_crc, qam_expected_crc, qam_active_crc;
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

#include "ris_qam_regs.h"
int ris_qam_stop(ris_controller *dev);
void ris_qam_cancel_upload(ris_controller *dev);
int ris_qam_begin(ris_controller *dev,u32 ticks,u32 k,u32 slots,u32 loop);
int ris_qam_counts(ris_controller *dev,u32 frames,u32 events,u32 bytes,u32 crc);
int ris_qam_data(ris_controller *dev,unsigned kind,u32 offset,const u8 *data,u32 bytes);
int ris_qam_start(ris_controller *dev,u32 crc);
u32 ris_qam_received(const ris_controller *dev);
u32 ris_qam_expected_bytes(const ris_controller *dev);
#endif
