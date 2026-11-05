#include "ris_controller.h"
#include "xil_io.h"
#include "xtime_l.h"

#define RIS_TIMEOUT_TICKS ((u64)COUNTS_PER_SECOND * 2u)
static int apply_raw(ris_controller *dev, const u8 image[50], u64 mask);

static void barrier(void)
{
    __asm__ volatile ("dmb sy" ::: "memory");
}

u32 ris_read(const ris_controller *dev, u32 offset)
{
    return Xil_In32(dev->base + offset);
}

static void ris_write(const ris_controller *dev, u32 offset, u32 value)
{
    Xil_Out32(dev->base + offset, value);
}

u64 ris_frame_count(const ris_controller *dev)
{
    u32 hi, lo, again;
    do {
        hi = ris_read(dev, RIS_REG_FRAME_COUNT_HI);
        lo = ris_read(dev, RIS_REG_FRAME_COUNT_LO);
        again = ris_read(dev, RIS_REG_FRAME_COUNT_HI);
    } while (hi != again);
    return ((u64)hi << 32) | lo;
}

static int expired(XTime start)
{
    XTime now;
    XTime_GetTime(&now);
    return now - start >= RIS_TIMEOUT_TICKS;
}

static int command(ris_controller *dev, u32 op_flags)
{
    XTime start;
    u32 id = dev->next_id++;
    if (dev->next_id == 0u) dev->next_id = 1u;
    ris_write(dev, RIS_REG_OP_FLAGS, op_flags);
    ris_write(dev, RIS_REG_CMD_ID, id);
    ris_write(dev, RIS_REG_ARG0, 0u);
    ris_write(dev, RIS_REG_ARG1, 0u);
    barrier();
    ris_write(dev, RIS_REG_COMMIT, 1u);
    barrier();
    if (ris_read(dev, RIS_REG_LAST_ACCEPTED) != id) return RIS_NOT_ACCEPTED;
    XTime_GetTime(&start);
    do {
        if ((ris_read(dev, RIS_REG_QUEUE_LEVEL) & 0xff00u) != 0u) {
            u32 result_id = ris_read(dev, RIS_REG_RESULT_ID);
            u32 result = ris_read(dev, RIS_REG_RESULT_CODE);
            ris_write(dev, RIS_REG_RESULT_POP, 1u);
            barrier();
            /* Initialization can encounter results retained across soft reset. */
            if (result_id == id) {
                dev->last_result = result;
                return result == RIS_RESULT_DONE ? RIS_OK : RIS_COMMAND_FAILED;
            }
        }
    } while (!expired(start));
    return RIS_TIMEOUT;
}

int ris_output_enable(ris_controller *dev, int enable)
{
    int stopped = RIS_OK;
    if (!enable) {
        stopped = ris_fast_stop(dev);
    }
    int rc = command(dev, enable ? RIS_OP_OUTPUT_ENABLE : RIS_OP_OUTPUT_DISABLE);
    if (rc != RIS_OK) return rc;
    if (!!(ris_read(dev, RIS_REG_STATUS) & RIS_STATUS_OUTPUT_ENABLED) != !!enable)
        return RIS_HARDWARE_ERROR;
    return stopped;
}

int ris_initialize(ris_controller *dev, UINTPTR base)
{
    XTime start;
    u32 n;
    int rc;
    dev->base = base;
    dev->last_result = 0u;
    dev->fast_supported = 0;
    dev->mt_supported = 0;
    dev->mt_expected = dev->mt_loaded = 0;
    if (ris_read(dev, RIS_REG_ID) != RIS_DEVICE_ID) return RIS_BAD_DEVICE;
    /* Discard old completed records; this program owns the peripheral. */
    for (n = 0u; n < 32u; ++n) {
        if ((ris_read(dev, RIS_REG_QUEUE_LEVEL) & 0xff00u) == 0u) break;
        ris_write(dev, RIS_REG_RESULT_POP, 1u);
    }
    dev->next_id = ris_read(dev, RIS_REG_LAST_ACCEPTED) + 1u;
    if (dev->next_id == 0u) dev->next_id = 1u;
    rc = command(dev, RIS_OP_SOFT_RESET);
    if (rc != RIS_OK) return rc;
    XTime_GetTime(&start);
    while ((ris_read(dev, RIS_REG_STATUS) & (RIS_STATUS_INITIALIZED | 7u | (1u << 5)))
           != (RIS_STATUS_INITIALIZED | 2u)) {
        if (expired(start)) return RIS_TIMEOUT;
    }
#ifdef RIS_FAST_TOGGLE
    if (ris_read(dev, RIS_REG_FAST_ID) != RIS_FAST_DEVICE_ID) return RIS_BAD_DEVICE;
    dev->fast_supported = 1;
#ifdef RIS_MT_TABLE
    /* Read only with a matching MT bitstream; legacy AXI returns DECERR here. */
    if (ris_read(dev, RIS_REG_MT_ID) != RIS_MT_DEVICE_ID) return RIS_BAD_DEVICE;
    dev->mt_supported = 1;
#endif
    XTime_GetTime(&start);
    while (!(ris_read(dev, RIS_REG_FAST_STATUS) & RIS_FAST_LOCKED)) {
        if (expired(start)) return RIS_TIMEOUT;
    }
#endif
    /* First-board setting: SHCP = 1 MHz, each guard/latch/recovery = 500 ns.
     * Full AXI/engine clock remains 100 MHz. No high-speed playback is needed. */
    ris_write(dev, RIS_REG_CFG_PERIOD, 10000u);
    ris_write(dev, RIS_REG_CFG_HALF, 50u);
    ris_write(dev, RIS_REG_CFG_GUARD, 50u);
    ris_write(dev, RIS_REG_CFG_LATCH, 50u);
    ris_write(dev, RIS_REG_CFG_RECOVERY, 50u);
    rc = command(dev, RIS_OP_CONFIG_APPLY);
    if (rc != RIS_OK) return rc;
    rc = ris_set_all(dev, 0);
    if (rc != RIS_OK) return rc;
    return ris_output_enable(dev, 1);
}

int ris_set_all(ris_controller *dev, int high)
{
    u8 image[50];
    u32 n;
    for (n=0; n<50; ++n) image[n]=high ? 0xffu : 0u;
    return ris_apply_pattern(dev, image, 0x3ffffffffffffULL);
}

int ris_apply_pattern(ris_controller *dev, const u8 image[50], u64 mask)
{
    int rc;
    if (!image || !mask || mask>>50) return RIS_NOT_ACCEPTED;
    rc = ris_fast_stop(dev);
    return rc == RIS_OK ? apply_raw(dev, image, mask) : rc;
}

static int apply_raw(ris_controller *dev, const u8 image[50], u64 mask)
{
    u32 expected[13];
    u32 n, b;
    u64 before = ris_frame_count(dev);
    int rc;
    if (!image || !mask || mask>>50) return RIS_NOT_ACCEPTED;
    for (n=0; n<13; ++n) {
        u32 word=0;
        expected[n]=ris_read(dev, RIS_REG_IMAGE+4u*n);
        for (b=0; b<4 && n*4+b<50; ++b) {
            u32 shift=b*8u;
            word|=(u32)image[n*4+b]<<shift;
            if (mask & (1ULL<<(n*4+b)))
                expected[n]=(expected[n]&~(0xffu<<shift)) | ((u32)image[n*4+b]<<shift);
        }
        ris_write(dev, RIS_REG_STAGE+4u*n, word);
    }
    ris_write(dev, RIS_REG_MASK_LO, (u32)mask);
    ris_write(dev, RIS_REG_MASK_HI, (u32)(mask>>32));
    rc = command(dev, RIS_OP_APPLY | RIS_FLAG_APPLY_HOLD);
    if (rc != RIS_OK) return rc;
    if (ris_frame_count(dev) != before + 1u) return RIS_HARDWARE_ERROR;
    for (n = 0u; n < 13u; ++n) {
        if (ris_read(dev, RIS_REG_IMAGE + 4u * n) != expected[n]) return RIS_IMAGE_MISMATCH;
    }
    if (ris_read(dev, RIS_REG_ERROR_FLAGS) != 0u) return RIS_HARDWARE_ERROR;
    return RIS_OK;
}

static int fast_control(ris_controller *dev, u32 value)
{
    XTime start;
    XTime_GetTime(&start);
    while (ris_read(dev, RIS_REG_FAST_STATUS) & RIS_FAST_PENDING)
        if (expired(start)) return RIS_TIMEOUT;
    ris_write(dev, RIS_REG_FAST_CONTROL, value);
    barrier();
    while (ris_read(dev, RIS_REG_FAST_STATUS) & RIS_FAST_PENDING)
        if (expired(start)) return RIS_TIMEOUT;
    return (ris_read(dev, RIS_REG_FAST_STATUS) & RIS_FAST_LOCKED) ? RIS_OK : RIS_HARDWARE_ERROR;
}

u32 ris_fast_mhz(const ris_controller *dev)
{
    u32 ticks = ris_fast_ticks(dev);
    return ticks==150 ? 1u : (ticks==50 ? 3u : (ticks==30 ? 5u : 0u));
}

u32 ris_fast_ticks(const ris_controller *dev)
{
    return dev->fast_supported ? ris_read(dev, RIS_REG_FAST_TICKS_ACTIVE) : 0;
}

int ris_fast_stop(ris_controller *dev)
{
    u32 status, n;
    u8 image[50];
    int rc;
    if (!dev->fast_supported) return RIS_OK;
    status = ris_read(dev, RIS_REG_FAST_STATUS);
    if (!(status & RIS_FAST_OWNED)) return RIS_OK;
    rc = fast_control(dev, 0); /* finish the frame; retain pin ownership */
    if (rc != RIS_OK) return rc;
    status = ris_read(dev, RIS_REG_FAST_STATUS);
    if (status & RIS_FAST_RUNNING) return RIS_HARDWARE_ERROR;
    for (n=0;n<50;++n) image[n]=(status & RIS_FAST_LEVEL) ? 255u : 0u;
    /* Align the normal engine before releasing pins: its shift clocks remain
     * hidden while FAST owns the outputs, preserving the last physical latch. */
    rc = apply_raw(dev, image, 0x3ffffffffffffULL);
    if (rc != RIS_OK) return rc;
    rc = fast_control(dev, 8);
    if (rc != RIS_OK) return rc;
    return (ris_read(dev, RIS_REG_FAST_STATUS) & RIS_FAST_OWNED) ? RIS_HARDWARE_ERROR : RIS_OK;
}

int ris_fast_start(ris_controller *dev, u32 mhz)
{
    if (mhz!=1 && mhz!=3 && mhz!=5) return RIS_NOT_ACCEPTED;
    return ris_fast_start_hz(dev, mhz*1000000u);
}

int ris_fast_start_hz(ris_controller *dev, u32 hz)
{
    if (!hz || hz>5000000u) return RIS_NOT_ACCEPTED;
    return ris_fast_start_ticks(dev, (RIS_FAST_HALF_CLOCK_HZ+hz/2u)/hz);
}

int ris_fast_start_ticks(ris_controller *dev, u32 half_ticks)
{
    int rc;
    u32 status;
    if (!dev->fast_supported || half_ticks<RIS_FAST_MIN_TICKS || half_ticks>RIS_FAST_MAX_TICKS)
        return RIS_NOT_ACCEPTED;
    rc = ris_fast_stop(dev);
    if (rc == RIS_OK) rc = ris_set_all(dev, 0);
    if (rc == RIS_OK) rc = ris_output_enable(dev, 1);
    if (rc == RIS_OK) {
        ris_write(dev, RIS_REG_FAST_TICKS_CONFIG, half_ticks);
        barrier();
        if (ris_read(dev, RIS_REG_FAST_TICKS_CONFIG)!=half_ticks) return RIS_HARDWARE_ERROR;
        rc = fast_control(dev, 9);
    }
    if (rc != RIS_OK) return rc;
    status = ris_read(dev, RIS_REG_FAST_STATUS);
    return (status & (RIS_FAST_OWNED|RIS_FAST_RUNNING|RIS_FAST_LOCKED)) ==
        (RIS_FAST_OWNED|RIS_FAST_RUNNING|RIS_FAST_LOCKED) && ris_fast_ticks(dev)==half_ticks ? RIS_OK : RIS_HARDWARE_ERROR;
}

void ris_mt_cancel_upload(ris_controller *dev)
{
    dev->mt_expected=dev->mt_loaded=0;
}

int ris_mt_begin(ris_controller *dev,u32 count,u32 loop_start,u32 period,u32 delay)
{
    int rc;
    if (!dev->mt_supported || !count || count>RIS_MT_CAPACITY || loop_start>=count ||
        period<60 || period>300000000u || delay>0x7fffffffu) return RIS_NOT_ACCEPTED;
    rc=ris_fast_stop(dev);
    if (rc) return rc;
    ris_mt_cancel_upload(dev);
    ris_write(dev,RIS_REG_MT_COUNT,0);
    ris_write(dev,RIS_REG_MT_LOOP_START,loop_start);
    ris_write(dev,RIS_REG_MT_PERIOD,period);
    ris_write(dev,RIS_REG_MT_DELAY,delay);
    barrier();
    if (ris_read(dev,RIS_REG_MT_COUNT)!=0 || ris_read(dev,RIS_REG_MT_LOOP_START)!=loop_start ||
        ris_read(dev,RIS_REG_MT_PERIOD)!=period || ris_read(dev,RIS_REG_MT_DELAY)!=delay)
        return RIS_HARDWARE_ERROR;
    dev->mt_expected=count;dev->mt_checksum=2166136261u;dev->mt_last_level=0;
    return RIS_OK;
}

int ris_mt_segment(ris_controller *dev,u32 index,u32 level,u32 ticks)
{
    u32 word;
    if (!dev->mt_supported || !dev->mt_expected || index!=dev->mt_loaded ||
        index>=dev->mt_expected || level>1 || ticks<30 || ticks>0x7fffffffu ||
        (ris_read(dev,RIS_REG_FAST_STATUS)&(RIS_FAST_OWNED|RIS_FAST_PENDING)))
        return RIS_NOT_ACCEPTED;
    word=(level<<31)|ticks;
    ris_write(dev,RIS_REG_MT_ADDRESS,index);
    ris_write(dev,RIS_REG_MT_DATA,word);
    barrier();
    if (ris_read(dev,RIS_REG_MT_DATA)!=word) {
        ris_mt_cancel_upload(dev);return RIS_HARDWARE_ERROR;
    }
    dev->mt_checksum=(dev->mt_checksum^word)*16777619u;
    dev->mt_last_level=level;++dev->mt_loaded;
    return RIS_OK;
}

int ris_mt_start(ris_controller *dev,u32 loop,u32 checksum)
{
    int rc;
    if (!dev->mt_supported || loop>1 || !dev->mt_expected ||
        dev->mt_loaded!=dev->mt_expected || dev->mt_checksum!=checksum ||
        (!loop && dev->mt_last_level)) return RIS_NOT_ACCEPTED;
    rc=ris_set_all(dev,0);
    if (!rc) rc=ris_output_enable(dev,1);
    if (rc) return rc;
    ris_write(dev,RIS_REG_MT_COUNT,dev->mt_expected);
    barrier();
    if (ris_read(dev,RIS_REG_MT_COUNT)!=dev->mt_expected) return RIS_HARDWARE_ERROR;
    rc=fast_control(dev,loop ? 11 : 10);
    /* A very short one-shot may already be complete by the first status read. */
    if (!rc && !(ris_read(dev,RIS_REG_MT_STATUS)&2u)) rc=RIS_HARDWARE_ERROR;
    ris_mt_cancel_upload(dev);
    return rc;
}
