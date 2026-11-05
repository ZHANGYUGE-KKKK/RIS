/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/* AD9361 SPI connectivity check. PS initialization is performed by the
 * Vitis launch configuration; UART output uses the BSP's 115200 baud rate.
 */
#include "platform.h"
#include "xil_printf.h"
#include "drivers/ad9361.h"
#include "drivers/gpio_ris.h"
#include "drivers/gpio_9361.h"
#include "drivers/dma_9361.h"
#include "drivers/mig_ddr.h"
#include "ad_config/ad_config.h"
#include "xparameters.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xpseudo_asm.h"
#include "xtime_l.h"
#include "sleep.h"
#include <string.h>

static ad9361_device radio;
static gpio_ris_device ris;
static gpio_9361_device capture;
static dma_9361_device receiver;
static ad_config_device rf_config;

/* Current BD routes FCLK_RESET0_N through rst_ps_fclk0 to the capture,
 * AXIS FIFO, DMA and AXI GPIO resets. Keep these blocks in reset while the
 * AD9361 interface clocks change. CPU, PS DDR, SPI0/1 and RESETB stay active.
 * UG585: SLCR FPGA_RST_CTRL[0], unlock/lock keys. Only use before DMA/ARM.
 */
static int rf_capture_reset(u32 asserted)
{
    u32 control = Xil_In32(0xF8000240U);
    u32 locked = Xil_In32(0xF800000CU) & 1U;
    u32 expected = asserted ? control | 1U : control & ~1U;
    u32 actual;
    /* Drain CPU AXI writes before taking the GP fabric into reset. */
    dsb();
    Xil_Out32(0xF8000008U, 0xDF0DU);
    Xil_Out32(0xF8000240U, expected);
    dsb();
    actual = Xil_In32(0xF8000240U);
    if (locked)
        Xil_Out32(0xF8000004U, 0x767BU);
    dsb();
    usleep(asserted ? 1000U : 10000U);
    return actual == expected ? 0 : -1;
}

volatile struct {
    u32 magic, done;
    s32 result;
    u32 checks, reference_hz, bbpll, rxpll, txpll, capture_status;
    u32 frame_checks, capture_flags_or;
} rf_clock_test_report;

/* Bounded board diagnostic. ARM stays zero; reset capture between settings
 * so sticky FRAME errors cannot contaminate another delay measurement.
 * Select a stable FRAME-window centre; IQ/PN must still be checked separately.
 * If no candidate passes, restore the original register and report failure.
 */
#define FMCOMMS3_RX_DELAY_SCAN 1
#if FMCOMMS3_RX_DELAY_SCAN
volatile struct {
    u32 magic, done;
    s32 result;
    u32 saved_delay, pass_count;
    u32 pass_mask[16];
    u32 status[256];
    u32 selected_delay, stable_checks;
} rx_align_report;

static int rf_rx_delay_scan(void)
{
    gpio_9361_device probe;
    u32 clock_tap, data_tap, repeat, flags, combined;
    u8 saved = 0U, value, actual;
    int result = -1;

    memset((void *)&rx_align_report, 0, sizeof(rx_align_report));
    rx_align_report.magic = 0x5258414CU;
    rx_align_report.result = -1;
    rx_align_report.selected_delay = 0xFFFFFFFFU;
    if (ad9361_reg_read(&radio, 0x006U, &saved) != AD9361_OK)
        goto finished;
    rx_align_report.saved_delay = saved;
    xil_printf("\r\nRX ALIGN SCAN: ARM=0, 16 clock x 16 data taps; original 006=%02x\r\n", (unsigned)saved);
    for (clock_tap = 0U; clock_tap < 16U; ++clock_tap) {
        for (data_tap = 0U; data_tap < 16U; ++data_tap) {
            value = (u8)((clock_tap << 4) | data_tap);
            if (rf_capture_reset(1U) != 0 ||
                ad9361_reg_write(&radio, 0x006U, value) != AD9361_OK ||
                ad9361_reg_read(&radio, 0x006U, &actual) != AD9361_OK ||
                actual != value ||
                rf_capture_reset(0U) != 0 ||
                gpio_9361_init(&probe) != GPIO_9361_OK)
                goto restore;
            combined = 0U;
            for (repeat = 0U; repeat < 4U; ++repeat) {
                usleep(2000U);
                if (gpio_9361_get_status(&probe, &flags) != GPIO_9361_OK)
                    goto restore;
                combined |= flags;
                if ((flags & 0x3FU) != 0x03U)
                    combined |= 0x80000000U;
            }
            rx_align_report.status[value] = combined;
            if (combined == 0x03U) {
                rx_align_report.pass_mask[clock_tap] |= 1U << data_tap;
                ++rx_align_report.pass_count;
            }
        }
        xil_printf("RX ALIGN clock=%x, data[15:0] pass_mask=%04x\r\n",
                   (unsigned)clock_tap, (unsigned)rx_align_report.pass_mask[clock_tap]);
    }
    /* Rank the centres of contiguous FRAME windows. A short scan only
     * nominates candidates; require 200 ms continuous lock before selection.
     * IQ validation remains a separate BIST/DMA test. */
    {
        u32 margin, left, right;
        for (margin = 8U; margin > 0U; --margin) {
            for (clock_tap = 0U; clock_tap < 16U; ++clock_tap) {
                for (data_tap = 0U; data_tap < 16U; ++data_tap) {
                    if (!(rx_align_report.pass_mask[clock_tap] & (1U << data_tap)))
                        continue;
                    left = data_tap; right = data_tap;
                    while (left && (rx_align_report.pass_mask[clock_tap] & (1U << (left - 1U)))) --left;
                    while (right < 15U && (rx_align_report.pass_mask[clock_tap] & (1U << (right + 1U)))) ++right;
                    if (1U + (data_tap - left < right - data_tap ? data_tap - left : right - data_tap) != margin)
                        continue;
                    value = (u8)((clock_tap << 4) | data_tap);
                    if (rf_capture_reset(1U) != 0 ||
                        ad9361_reg_write(&radio, 0x006U, value) != AD9361_OK ||
                        rf_capture_reset(0U) != 0 || gpio_9361_init(&probe) != GPIO_9361_OK)
                        goto restore;
                    for (repeat = 0U; repeat < 100U; ++repeat) {
                        usleep(2000U);
                        if (gpio_9361_get_status(&probe, &flags) != GPIO_9361_OK || flags != 0x03U)
                            break;
                    }
                    if (repeat == 100U) {
                        rx_align_report.selected_delay = value;
                        rx_align_report.stable_checks = repeat;
                        saved = value;
                        result = 0;
                        goto restore;
                    }
                }
            }
        }
    }
restore:
    if (rf_capture_reset(1U) != 0 ||
        ad9361_reg_write(&radio, 0x006U, saved) != AD9361_OK ||
        ad9361_check_online(&radio) != AD9361_OK)
        result = -1;
finished:
    rx_align_report.result = result;
    dsb(); rx_align_report.done = 1U; dsb();
    xil_printf("RX ALIGN SCAN complete: result=%d pass=%d/256, applied 006=%02x\r\n",
               result, (unsigned)rx_align_report.pass_count, (unsigned)saved);
    return result;
}
#endif

/* FMCOMMS3 uses its 40 MHz crystal; verify AD9361 PLLs after RF setup.
 * PLL readbacks are lock evidence; they are not a frequency-meter reading.
 */
static int rf_clock_selftest(void)
{
    u32 i, capture_flags = 0U;
    u8 bbpll = 0U, rxpll = 0U, txpll = 0U;
    int result = 0;

    memset((void *)&rf_clock_test_report, 0, sizeof(rf_clock_test_report));
    rf_clock_test_report.magic = 0x5246434BU;
    rf_clock_test_report.result = -1;
    for (i = 0U; i < 20U; ++i) {
        if (ad9361_reg_read(&radio, 0x05EU, &bbpll) != AD9361_OK ||
            ad9361_reg_read(&radio, 0x247U, &rxpll) != AD9361_OK ||
            ad9361_reg_read(&radio, 0x287U, &txpll) != AD9361_OK ||
            (bbpll & 0x80U) == 0U || (rxpll & 0x02U) == 0U ||
            (txpll & 0x02U) == 0U) {
            result = -1;
            break;
        }
        if (gpio_9361_get_status(&capture, &capture_flags) == GPIO_9361_OK) {
            rf_clock_test_report.capture_flags_or |= capture_flags;
            if ((capture_flags & GPIO_9361_STATUS_MASK) ==
                (GPIO_9361_READY_MASK | GPIO_9361_FRAME_LOCKED_MASK))
                ++rf_clock_test_report.frame_checks;
        }
        ++rf_clock_test_report.checks;
        usleep(100000U);
    }
    (void)gpio_9361_get_status(&capture, &capture_flags);
    rf_clock_test_report.reference_hz = 40000000U;
    rf_clock_test_report.bbpll = bbpll;
    rf_clock_test_report.rxpll = rxpll;
    rf_clock_test_report.txpll = txpll;
    rf_clock_test_report.capture_status = capture_flags;
    rf_clock_test_report.result = result;
    dsb(); rf_clock_test_report.done = 1U; dsb();
    xil_printf("RF CLOCK TEST %s: %d/20 checks over 2 s; FMCOMMS3 XTAL=40 MHz BBPLL=%02x RXPLL=%02x TXPLL=%02x\r\n",
               result == 0 ? "PASS" : "FAILED", (unsigned int)rf_clock_test_report.checks,
               (unsigned int)bbpll,
               (unsigned int)rxpll, (unsigned int)txpll);
    xil_printf("RX interface: READY=%d FRAME_LOCKED=%d errors=0x%02x; ARM=0\r\n",
               (capture_flags & GPIO_9361_READY_MASK) != 0U,
               (capture_flags & GPIO_9361_FRAME_LOCKED_MASK) != 0U,
               (unsigned int)(capture_flags & GPIO_9361_ERROR_MASK));
    xil_printf("RX FRAME TEST %s: %d/20 stable locked checks, combined status=0x%02x\r\n",
               rf_clock_test_report.frame_checks == 20U ? "PASS" : "FAILED",
               (unsigned)rf_clock_test_report.frame_checks,
               (unsigned)rf_clock_test_report.capture_flags_or);
    return result;
}

/* Destructive scratch test, separate from the default DMA BDs at 0x40000000
 * and RX payload at 0x40100000..0x408FFFFF. Code/stack/report stay in PS DDR.
 * Before calling: MIG calibrated, ui_clk_sync_rst=0, mmcm_locked=1,
 * peripheral_aresetn=1; capture and DMA must remain stopped.
 * These ILA-only signals have no software register in the current BD.
 */
#define MIG_TEST_BASE       0x41000000U
#define MIG_TEST_SMALL      0x00010000U
#define MIG_TEST_LARGE      0x00800000U
#define MIG_TEST_MAX_ERRORS 16U

typedef struct {
    u32 address;
    u32 expected;
    u32 actual;
} mig_test_mismatch;

/* Visible in Vitis/XSDB even if the first AXI transaction stalls. done=1
 * means the function returned; result=0 only after every stage passed.
 */
volatile struct {
    u32 magic;
    u32 done;
    s32 result;
    u32 stage;
    u32 passed_stages;
    u32 errors;
    u32 current_address;
    u32 checked_words;
    u32 elapsed_ms;
    mig_test_mismatch mismatch[MIG_TEST_MAX_ERRORS];
} mig_test_report;

enum mig_test_pattern { MIG_TEST_FIXED, MIG_TEST_ADDRESS, MIG_TEST_RANDOM };

static u32 mig_test_random(u32 *state)
{
    u32 value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

static int mig_test_compare(UINTPTR address, u32 expected)
{
    u32 actual;
    u32 error;

    mig_test_report.current_address = (u32)address;
    actual = *(volatile u32 *)address;
    ++mig_test_report.checked_words;
    if (actual == expected)
        return 0;
    error = mig_test_report.errors;
    if (error < MIG_TEST_MAX_ERRORS) {
        mig_test_report.mismatch[error].address = (u32)address;
        mig_test_report.mismatch[error].expected = expected;
        mig_test_report.mismatch[error].actual = actual;
        xil_printf("  ERROR @0x%08x: expected=0x%08x actual=0x%08x xor=0x%08x\r\n",
                   (unsigned int)address, (unsigned int)expected,
                   (unsigned int)actual, (unsigned int)(expected ^ actual));
    }
    ++mig_test_report.errors;
    return -1;
}

/* Fill the ENTIRE region before reading it back: a write/read of each word
 * immediately would hide many address aliases. All accesses are uncached.
 */
static int mig_test_block(UINTPTR base, u32 bytes,
                          enum mig_test_pattern pattern, u32 seed)
{
    u32 offset, value, state = seed;
    UINTPTR address;

    for (offset = 0U; offset < bytes; offset += sizeof(u32)) {
        address = base + offset;
        value = pattern == MIG_TEST_FIXED ? seed :
                pattern == MIG_TEST_ADDRESS ? (u32)address ^ seed :
                mig_test_random(&state);
        mig_test_report.current_address = (u32)address;
        *(volatile u32 *)address = value;
    }
    dsb();
    state = seed;
    for (offset = 0U; offset < bytes; offset += sizeof(u32)) {
        address = base + offset;
        value = pattern == MIG_TEST_FIXED ? seed :
                pattern == MIG_TEST_ADDRESS ? (u32)address ^ seed :
                mig_test_random(&state);
        (void)mig_test_compare(address, value);
        if (mig_test_report.errors >= MIG_TEST_MAX_ERRORS)
            break;
    }
    dsb();
    return mig_test_report.errors == 0U ? 0 : -1;
}

static int mig_test_strobes(void)
{
    volatile u32 *words = (volatile u32 *)(MIG_TEST_BASE + 0x20000U);
    u32 expected[8];
    u32 word, lane, index, mask, value;

    for (word = 0U; word < 8U; ++word) {
        expected[word] = 0x13579BDFU ^ (word * 0x01010101U);
        words[word] = expected[word];
    }
    dsb();
    /* Check all eight neighbours after each 32-, 8- and 16-bit update in
     * the same 256-bit MIG AXI beat, including little-endian byte lanes.
     */
    for (word = 0U; word < 8U; ++word) {
        for (lane = 0U; lane < 7U; ++lane) {
            if (lane == 0U) {
                expected[word] ^= 0xA55A6996U;
                words[word] = expected[word];
            } else if (lane <= 4U) {
                index = lane - 1U;
                value = (0xA6U + word + index) & 0xFFU;
                mask = 0xFFU << (index * 8U);
                expected[word] = (expected[word] & ~mask) | (value << (index * 8U));
                ((volatile u8 *)&words[word])[index] = (u8)value;
            } else {
                index = lane - 5U;
                value = 0x5AC3U ^ (word << 8) ^ index;
                mask = 0xFFFFU << (index * 16U);
                expected[word] = (expected[word] & ~mask) | (value << (index * 16U));
                ((volatile u16 *)&words[word])[index] = (u16)value;
            }
            dsb();
            for (index = 0U; index < 8U; ++index)
                (void)mig_test_compare((UINTPTR)&words[index], expected[index]);
            if (mig_test_report.errors != 0U)
                return -1;
        }
    }
    return 0;
}

static const UINTPTR mig_test_windows[] = {
    MIG_TEST_BASE, 0x49000000U, 0x51000000U, 0x61000000U, 0x7FFF0000U
};

static int mig_test_aliases(void)
{
    UINTPTR probes[30];
    u32 bit, count = 0U, index, round, seed;

    probes[count++] = MIG_TEST_BASE;
    for (bit = 2U; bit <= 29U; ++bit)
        probes[count++] = MIG_TEST_BASE + (1U << bit);
    probes[count++] = 0x7FFFFFFCU;
    for (round = 0U; round < 2U; ++round) {
        seed = round == 0U ? 0x5AA55AA5U : 0xA55AA55AU;
        for (index = 0U; index < count; ++index)
            *(volatile u32 *)probes[index] = (u32)probes[index] ^ seed;
        dsb();
        for (index = 0U; index < count; ++index)
            (void)mig_test_compare(probes[index], (u32)probes[index] ^ seed);
        if (mig_test_report.errors != 0U)
            return -1;
    }
    return 0;
}

static int mig_test_sparse_windows(void)
{
    u32 window, offset;
    UINTPTR address;

    /* Write ALL windows before checking ANY window, so a truncated high
     * address cannot make several aliased windows each pass independently.
     */
    for (window = 0U; window < sizeof(mig_test_windows) / sizeof(mig_test_windows[0]); ++window)
        for (offset = 0U; offset < MIG_TEST_SMALL; offset += sizeof(u32)) {
            address = mig_test_windows[window] + offset;
            mig_test_report.current_address = (u32)address;
            *(volatile u32 *)address = (u32)address ^ 0xC35A96E1U;
        }
    dsb();
    for (window = 0U; window < sizeof(mig_test_windows) / sizeof(mig_test_windows[0]); ++window)
        for (offset = 0U; offset < MIG_TEST_SMALL; offset += sizeof(u32)) {
            address = mig_test_windows[window] + offset;
            (void)mig_test_compare(address, (u32)address ^ 0xC35A96E1U);
            if (mig_test_report.errors >= MIG_TEST_MAX_ERRORS)
                return -1;
        }
    return mig_test_report.errors == 0U ? 0 : -1;
}

/* A CPU memory test, not a DMA throughput or complete 1 GiB cell test.
 * Returns 0 on PASS, -stage on memory failure, -100 on failed preconditions.
 * An AXI transaction that never responds cannot be timed out by this loop;
 * stage/current_address in PS DDR and ILA reset flags locate such a stall.
 */
static int mig_ddr_selftest(void)
{
    static const u32 fixed[] = { 0U, 0xFFFFFFFFU, 0x55555555U, 0xAAAAAAAAU };
    static const u32 seeds[] = { 0x12345678U, 0x89ABCDEFU, 0x31415926U };
    static const char *const names[] = {
        "16-word access", "64 KiB fixed patterns", "64 KiB walking 1/0",
        "64 KiB address patterns", "256-bit beat write strobes",
        "4 KiB / 1 MiB boundaries", "8 MiB random, 3 passes",
        "address-bit aliases", "sparse windows / DDR upper boundary"
    };
    XTime started, now, stage_started;
    u32 stage, index, bit, capture_flags;
    int result = -100;

    memset((void *)&mig_test_report, 0, sizeof(mig_test_report));
    mig_test_report.magic = 0x4D494754U; /* MIGT */
    mig_test_report.result = -100;
    XTime_GetTime(&started);
    xil_printf("\r\nMIG SELFTEST: CPU uncached, DMA stopped, capture ARM=0\r\n");
    xil_printf("Scratch: 0x41000000..0x417FFFFF; sparse 0x49000000/0x51000000/0x61000000; top 64 KiB\r\n");
    xil_printf("Prerequisite (ILA): ui_rst=0, aresetn=1, locked=1, calib_done=1\r\n");
    if (!receiver.ready || receiver.state != DMA_9361_IDLE || receiver.started ||
        receiver.needs_pl_reset || !capture.ready || capture.armed ||
        gpio_9361_get_status(&capture, &capture_flags) != GPIO_9361_OK ||
        (capture_flags & GPIO_9361_ACTIVE_MASK) != 0U ||
        XAxiDma_BdRingHwIsStarted(XAxiDma_GetRxRing(&receiver.dma))) {
        xil_printf("MIG SELFTEST SKIPPED: capture/DMA must be initialized and idle\r\n");
        goto finished;
    }
    result = mig_ddr_map_uncached(&receiver.memory, MIG_TEST_BASE, MIG_TEST_LARGE);
    if (result != MIG_DDR_OK)
        goto mapping_failed;
    for (index = 0U; index < sizeof(mig_test_windows) / sizeof(mig_test_windows[0]); ++index) {
        result = mig_ddr_map_uncached(&receiver.memory, mig_test_windows[index], MIG_TEST_SMALL);
        if (result != MIG_DDR_OK)
            goto mapping_failed;
    }
    /* Some one-hot address probes lie outside the contiguous test windows.
     * Map the enclosing sections now, before any memory writes or DMA use.
     */
    for (bit = 2U; bit <= 29U; ++bit) {
        result = mig_ddr_map_uncached(&receiver.memory,
                                      (MIG_TEST_BASE + (1U << bit)) & ~31U, 32U);
        if (result != MIG_DDR_OK)
            goto mapping_failed;
    }
    for (stage = 1U; stage <= sizeof(names) / sizeof(names[0]); ++stage) {
        mig_test_report.stage = stage;
        XTime_GetTime(&stage_started);
        xil_printf("MIG [%d/9] %s: BEGIN\r\n", (int)stage, names[stage - 1U]);
        result = 0;
        switch (stage) {
        case 1U:
            result = mig_test_block(MIG_TEST_BASE, 64U, MIG_TEST_ADDRESS, 0x13579BDFU);
            break;
        case 2U:
            for (index = 0U; index < sizeof(fixed) / sizeof(fixed[0]) && result == 0; ++index)
                result = mig_test_block(MIG_TEST_BASE, MIG_TEST_SMALL, MIG_TEST_FIXED, fixed[index]);
            break;
        case 3U:
            for (bit = 0U; bit < 32U && result == 0; ++bit) {
                result = mig_test_block(MIG_TEST_BASE, MIG_TEST_SMALL, MIG_TEST_FIXED, 1U << bit);
                if (result == 0)
                    result = mig_test_block(MIG_TEST_BASE, MIG_TEST_SMALL, MIG_TEST_FIXED, ~(1U << bit));
            }
            break;
        case 4U:
            result = mig_test_block(MIG_TEST_BASE, MIG_TEST_SMALL, MIG_TEST_ADDRESS, 0xA5963C5AU);
            if (result == 0)
                result = mig_test_block(MIG_TEST_BASE, MIG_TEST_SMALL, MIG_TEST_ADDRESS, 0x5A69C3A5U);
            break;
        case 5U:
            result = mig_test_strobes();
            break;
        case 6U:
            result = mig_test_block(MIG_TEST_BASE + 0xFE0U, 64U, MIG_TEST_ADDRESS, 0x1B2C3D4EU);
            if (result == 0)
                result = mig_test_block(MIG_TEST_BASE + 0xFFFE0U, 64U, MIG_TEST_ADDRESS, 0x4E3D2C1BU);
            break;
        case 7U:
            for (index = 0U; index < sizeof(seeds) / sizeof(seeds[0]) && result == 0; ++index) {
                xil_printf("  random pass %d/3, seed=0x%08x\r\n", (int)index + 1, (unsigned int)seeds[index]);
                result = mig_test_block(MIG_TEST_BASE, MIG_TEST_LARGE, MIG_TEST_RANDOM, seeds[index]);
            }
            break;
        case 8U:
            result = mig_test_aliases();
            break;
        case 9U:
            result = mig_test_sparse_windows();
            break;
        }
        XTime_GetTime(&now);
        xil_printf("MIG [%d/9] %s: %s, %d ms\r\n", (int)stage, names[stage - 1U],
                   result == 0 ? "PASS" : "FAIL",
                   (unsigned int)((now - stage_started) / (COUNTS_PER_SECOND / 1000U)));
        if (result != 0) {
            result = -(int)stage;
            goto finished;
        }
        ++mig_test_report.passed_stages;
    }
    goto finished;

mapping_failed:
    xil_printf("MIG SELFTEST mapping failed (%d): %s\r\n", result, mig_ddr_status_string(result));
    result = -100;
finished:
    XTime_GetTime(&now);
    mig_test_report.elapsed_ms = (u32)((now - started) / (COUNTS_PER_SECOND / 1000U));
    mig_test_report.result = result;
    dsb();
    mig_test_report.done = 1U;
    dsb();
    xil_printf("MIG SELFTEST %s: stages=%d/9, errors=%d, checked_words=%d, elapsed=%d ms, result=%d\r\n",
               result == 0 ? "PASS" : "FAILED", (int)mig_test_report.passed_stages,
               (int)mig_test_report.errors, (unsigned int)mig_test_report.checked_words,
               (unsigned int)mig_test_report.elapsed_ms, result);
    return result;
}

volatile struct {
    u32 magic, done;
    s32 result;
    u32 sample_count, buffer_address, received_bytes;
    u32 malformed_samples, period_errors, restore_status;
    u32 stage;
    s32 minimum[4], maximum[4];
} rx_bist_report;

#define FMCOMMS3_BIST_DELAY_SCAN 0
#if FMCOMMS3_BIST_DELAY_SCAN && !FMCOMMS3_RX_DELAY_SCAN
#error "BIST delay scan requires the FRAME-window scan"
#endif
#if FMCOMMS3_BIST_DELAY_SCAN
volatile struct {
    u32 magic, done, tested, best_delay, best_errors;
    s32 result[256];
    u32 errors[256];
} rx_bist_scan_report;
#endif

/* One finite diagnostic window from the AD9361 digital RX port into MIG.
 * Analyse the completed DDR window before resetting the source/AXI fabric.
 * The source is sticky-armed and may latch overflow after this finite DMA;
 * restore normal RX with ARM=0 by resetting FIFOs/DMA after analysis.
 */
static int rf_rx_bist_selftest(void)
{
    const dma_9361_sample *samples = NULL;
    s16 components[4], expected[4];
    u32 count = 0U, n, component;
    int result = -1, restore_result = 0;

    memset((void *)&rx_bist_report, 0, sizeof(rx_bist_report));
    rx_bist_report.magic = 0x52584254U;
    rx_bist_report.result = -1;
    rx_bist_report.buffer_address = DMA_9361_DEFAULT_BUFFER;
    for (component = 0U; component < 4U; ++component) {
        rx_bist_report.minimum[component] = 32767;
        rx_bist_report.maximum[component] = -32768;
    }
    xil_printf("\r\nRX BIST DMA TEST: %d Hz, period=%d, 4 packets / 16384 IQ tuples\r\n",
               AD_CONFIG_BIST_TONE_HZ, AD_CONFIG_BIST_PERIOD);
    rx_bist_report.stage = 1U;
    if (ad_config_rx_bist_tone(&rf_config, 1U) != AD_CONFIG_OK ||
        gpio_9361_wait_ready(&capture, 100000U) != GPIO_9361_OK)
        goto restore;
    /* Initial ARM is zero and no DMA has run. Keep the tested MIG/AXI
     * fabric live rather than resetting an interconnect after CPU traffic. */
    rx_bist_report.stage = 2U;
    xil_printf("RX BIST: preparing SG descriptors\r\n");
    result = dma_9361_prepare(&receiver, DMA_9361_DEFAULT_BD_BASE,
                              DMA_9361_DEFAULT_BUFFER, 4U);
    if (result != DMA_9361_OK)
        goto restore;
    rx_bist_report.stage = 3U;
    xil_printf("RX BIST: starting DMA\r\n");
    result = dma_9361_start(&receiver);
    if (result != DMA_9361_OK)
        goto restore;
    rx_bist_report.stage = 4U;
    result = dma_9361_wait(&receiver, 1000000U);
    if (result != DMA_9361_OK)
        goto restore;
    result = dma_9361_get_samples(&receiver, &samples, &count);
    if (result != DMA_9361_OK)
        goto restore;
    rx_bist_report.sample_count = count;
    rx_bist_report.received_bytes = receiver.received_bytes;
    rx_bist_report.stage = 5U;
    for (n = 0U; n < count; ++n) {
        memcpy(components, &samples[n], sizeof(components));
        memcpy(expected, &samples[n % AD_CONFIG_BIST_PERIOD], sizeof(expected));
        for (component = 0U; component < 4U; ++component) {
            s32 v = components[component];
            if (v < -2048 || v > 2047)
                ++rx_bist_report.malformed_samples;
            if (v < rx_bist_report.minimum[component])
                rx_bist_report.minimum[component] = v;
            if (v > rx_bist_report.maximum[component])
                rx_bist_report.maximum[component] = v;
            if (n >= AD_CONFIG_BIST_PERIOD && v != expected[component])
                ++rx_bist_report.period_errors;
        }
    }
    if (count != 16384U || receiver.received_bytes != 131072U ||
        rx_bist_report.malformed_samples != 0U || rx_bist_report.period_errors != 0U)
        result = -1;
    for (component = 0U; component < 4U; ++component)
        if (rx_bist_report.minimum[component] >= 0 || rx_bist_report.maximum[component] <= 0)
            result = -1;
restore:
    rx_bist_report.stage = 6U;
    if (result != 0)
        xil_printf("RX BIST test failed: result=%d DMA=%08x BD=%08x RX=%02x\r\n",
                   result, (unsigned)receiver.last_dma_status,
                   (unsigned)receiver.last_bd_status, (unsigned)receiver.last_capture_status);
    if (rf_capture_reset(1U) != 0)
        restore_result = -1;
    if (ad_config_rx_bist_tone(&rf_config, 0U) != AD_CONFIG_OK)
        restore_result = -1;
    if (rf_capture_reset(0U) != 0 || gpio_ris_init(&ris) != GPIO_RIS_OK ||
        gpio_9361_init(&capture) != GPIO_9361_OK ||
        dma_9361_init(&receiver, &capture) != DMA_9361_OK ||
        gpio_9361_wait_ready(&capture, 100000U) != GPIO_9361_OK)
        restore_result = -1;
    if (restore_result != 0)
        result = -1;
    rx_bist_report.restore_status = (u32)restore_result;
    rx_bist_report.result = result;
    dsb(); rx_bist_report.done = 1U; dsb();
    xil_printf("RX BIST DMA TEST %s: samples=%d bytes=%d malformed=%d period_errors=%d restore=%d; ARM=0\r\n",
               result == 0 ? "PASS" : "FAILED", (unsigned)rx_bist_report.sample_count,
               (unsigned)rx_bist_report.received_bytes, (unsigned)rx_bist_report.malformed_samples,
               (unsigned)rx_bist_report.period_errors, restore_result);
    for (component = 0U; component < 4U; ++component)
        xil_printf("RX BIST component %d min=%d max=%d\r\n", (unsigned)component,
                   (int)rx_bist_report.minimum[component], (int)rx_bist_report.maximum[component]);
    return result;
}

/* GUI-script test path. It intentionally bypasses both no-OS initialization
 * and RX-injected BIST, so the user file and RF input are not overwritten. */
static int config915_test_main(void)
{
    int result, dma_result;
    u32 flags = 0U;
    xil_printf("\r\nCONFIG915 board test: user GUI script, no reference-profile overwrite\r\n");
    if (rf_capture_reset(1U) != 0)
        return 1;
    result = ad9361_init(&radio);
    xil_printf("CONFIG915 SPI/reset result=%d PRODUCT_ID=%02x RESETB=%d/%d\r\n",
               result, radio.product_id, radio.reset_low_readback, radio.reset_high_readback);
    if (result == AD9361_OK)
        result = ad_config_init_915(&rf_config, &radio);
    if (rf_capture_reset(0U) != 0)
        return 1;
    (void)gpio_ris_init(&ris);
    (void)gpio_9361_init(&capture);
    if (result == 0) {
#if FMCOMMS3_RX_DELAY_SCAN
        u8 original_port = 0U, original_delay = 0U;
        if (ad9361_reg_read(&radio, 0x010U, &original_port) == AD9361_OK &&
            ad9361_reg_read(&radio, 0x006U, &original_delay) == AD9361_OK) {
            (void)rf_rx_delay_scan();
            if (rx_align_report.result != 0) {
                xil_printf("CONFIG915 FRAME: trying opposite DATA_CLK polarity\r\n");
                if (rf_capture_reset(1U) == 0 &&
                    ad9361_reg_write(&radio, 0x010U, original_port ^ 1U) == AD9361_OK)
                    (void)rf_rx_delay_scan();
            }
            if (rx_align_report.result != 0) {
                (void)rf_capture_reset(1U);
                (void)ad9361_reg_write(&radio, 0x010U, original_port);
                (void)ad9361_reg_write(&radio, 0x006U, original_delay);
                xil_printf("CONFIG915 FRAME: no stable window; original 010/006 restored\r\n");
            }
            (void)rf_capture_reset(0U);
            (void)gpio_ris_init(&ris);
            (void)gpio_9361_init(&capture);
        }
#endif
        (void)rf_clock_selftest();
        dma_result = dma_9361_init(&receiver, &capture);
        xil_printf("CONFIG915 DMA init result=%d; FRAME checks=%d/20\r\n",
                   dma_result, (unsigned)rf_clock_test_report.frame_checks);
        if (dma_result == DMA_9361_OK)
            (void)mig_ddr_selftest();
        (void)gpio_9361_get_status(&capture, &flags);
        xil_printf("CONFIG915 ACTIVE: RX/TX=915 MHz, Fs~15.36 MSPS, TX1 BIST~960 kHz\r\n");
        xil_printf("CONFIG915 TX1A -> external 30 dB attenuator -> RX1A; TX attenuation=20 dB\r\n");
        xil_printf("CONFIG915 RF capture awaits valid FRAME and loopback cable; GPIO=%02x ARM=0\r\n",
                   flags);
        xil_printf("CONFIG915 RX BIST remains OFF; TX BIST remains ON for RF loopback test\r\n");
    }
    Xil_DCacheFlush(); dsb();
    cleanup_platform();
    return result == 0 ? 0 : 1;
}

int main()
{
    int status;
    int ris_status;
    int capture_status;
    int dma_status;
    int mig_status;
    int config_status;
    int clock_test_status = -1;
    int bist_status = -1;

    init_platform();
    if (AD_CONFIG_USE_CONFIG915)
        return config915_test_main();
    xil_printf("\r\nRF bring-up: hold capture/FIFO/DMA in FCLK0 reset during clock configuration\r\n");
    if (rf_capture_reset(1U) != 0) {
        xil_printf("FCLK0 reset assertion failed\r\n");
        cleanup_platform();
        return 1;
    }
    xil_printf("\r\nFMCOMMS3 Rev.A AD9361 SPI bring-up; onboard 40 MHz crystal\r\n");
    xil_printf("SPI0 EMIO, SS0, mode 1; checking connectivity\r\n");
    xil_printf("RESETB: EMIO[%d], PS GPIO pin %d, FMC H31 / FPGA AC29\r\n",
               (int)AD9361_RESET_EMIO_INDEX, (int)AD9361_RESET_GPIO_PIN);

    status = ad9361_init(&radio);
    if (radio.gpio_ready)
        xil_printf("RESETB feedback: asserted=%d, released=%d\r\n",
                   (int)radio.reset_low_readback, (int)radio.reset_high_readback);
    if (radio.reset_done)
        xil_printf("RESETB hardware reset: low 1 ms, high 1 ms, pad feedback OK\r\n");
    xil_printf("SPI clock: %d Hz; PRODUCT_ID[0x037]=0x%02x\r\n",
               (int)radio.spi_clk_hz, (unsigned int)radio.product_id);
    if (status == AD9361_OK) {
        xil_printf("AD9361 ONLINE: revision=%d, SPI_CONF[0x000]=0x%02x\r\n",
                   (int)(radio.product_id & AD9361_REVISION_MASK),
                   (unsigned int)radio.spi_conf);
        xil_printf("PASS: 8 stable ID reads and SPI mode readback\r\n");
        xil_printf("Connectivity initialization complete; RF operating parameters not configured\r\n");
    } else {
        xil_printf("AD9361 CHECK FAILED (%d): %s\r\n", status,
                   ad9361_status_string(status));
        xil_printf("Last register=0x%03x, SPI status=0x%08x\r\n",
                   (unsigned int)radio.last_register,
                   (unsigned int)radio.last_spi_status);
        xil_printf("Check FMC power/VADJ, RESETB high, SPI wiring, and PS/PL initialization\r\n");
    }

    config_status = status == AD9361_OK ?
                    ad_config_init(&rf_config, &radio) : AD_CONFIG_ERR_NOT_READY;
    if (config_status != AD_CONFIG_OK)
        xil_printf("RF configuration failed (%d): %s\r\n", config_status,
                   ad_config_status_string(config_status));
    /* Scan ordinary RX FRAME after reference configuration (initial 006=04).
     * BIST is enabled only inside the optional DMA self-test below. */
    if (config_status == AD_CONFIG_OK)
        usleep(1000U);
#if FMCOMMS3_RX_DELAY_SCAN
    if (config_status == AD_CONFIG_OK)
        (void)rf_rx_delay_scan();
#endif
    if (rf_capture_reset(0U) != 0) {
        xil_printf("FCLK0 reset release failed\r\n");
        cleanup_platform();
        return 1;
    }
    xil_printf("Capture/FIFO/DMA reset released after RF clock configuration\r\n");
    ris_status = gpio_ris_init(&ris);
    if (ris_status == GPIO_RIS_OK) {
        xil_printf("\r\nRIS AXI GPIO @0x%08x: MONITOR, command=0x%08x\r\n",
                   (unsigned int)XPAR_AXI_GPIO_RIS_CTL_BASEADDR,
                   (unsigned int)ris.last_command);
    } else {
        xil_printf("\r\nRIS GPIO INIT FAILED (%d): %s\r\n", ris_status,
                   gpio_ris_status_string(ris_status));
    }
    capture_status = gpio_9361_init(&capture);
    if (capture_status == GPIO_9361_OK) {
        xil_printf("\r\nCAPTURE GPIO @0x%08x: ARM command=0, status=0x%02x\r\n",
                   (unsigned int)XPAR_AXI_GPIO_9361_BASEADDR,
                   (unsigned int)capture.last_status);
    } else {
        xil_printf("\r\nCAPTURE GPIO INIT FAILED (%d): %s\r\n",
                   capture_status, gpio_9361_status_string(capture_status));
    }
    /* Report RF initialization before any PL-DDR memory test. A stalled
     * memory transaction must not hide the independent AD9361 result.
     */
    if (config_status == AD_CONFIG_OK) {
        clock_test_status = rf_clock_selftest();
        gpio_9361_get_status(&capture, &capture.last_status);
        xil_printf("RF configuration complete; capture ARM=0, status=0x%02x\r\n",
                   (unsigned int)capture.last_status);
        xil_printf("FMCOMMS3 INITIALIZATION %s: SPI/reset, RF calibration, parameter readback, PLL stability\r\n",
                   clock_test_status == 0 && rf_clock_test_report.frame_checks == 20U ? "PASS" : "FAILED");
    }

    dma_status = capture_status == GPIO_9361_OK ?
                 dma_9361_init(&receiver, &capture) : DMA_9361_ERR_NOT_READY;
    if (dma_status == DMA_9361_OK) {
        xil_printf("AXI DMA @0x%08x: SG S2MM, 64-bit IQ, polling\r\n",
                   (unsigned int)XPAR_AXI_DMA_0_BASEADDR);
        xil_printf("MIG DDR: 0x%08x..0x%08x; memory access awaits calibration\r\n",
                   (unsigned int)receiver.memory.base,
                   (unsigned int)receiver.memory.high);
        xil_printf("Capture drivers initialized; configure RX clocks/FRAME before ARM\r\n");
    } else {
        xil_printf("CAPTURE DMA INIT FAILED (%d): %s\r\n", dma_status,
                   dma_9361_status_string(dma_status));
    }

    mig_status = mig_ddr_selftest();
    if (mig_status == 0 && config_status == AD_CONFIG_OK &&
        clock_test_status == 0 && rf_clock_test_report.frame_checks == 20U) {
#if FMCOMMS3_BIST_DELAY_SCAN
        u32 delay, selected_delay = rx_align_report.selected_delay;
        memset((void *)&rx_bist_scan_report, 0, sizeof(rx_bist_scan_report));
        rx_bist_scan_report.magic = 0x4253434EU;
        rx_bist_scan_report.best_errors = 0xFFFFFFFFU;
        for (delay = 0; delay < 256U; ++delay) {
            rx_bist_scan_report.result[delay] = DMA_9361_ERR_NOT_READY;
            rx_bist_scan_report.errors[delay] = 0xFFFFFFFFU;
        }
        for (delay = 0; delay < 256U; ++delay) {
            if (!(rx_align_report.pass_mask[delay >> 4] & (1U << (delay & 15U))))
                continue;
            xil_printf("RX BIST DELAY SCAN: 006=%02x\r\n", (unsigned)delay);
            if (rf_capture_reset(1U) != 0 ||
                ad9361_reg_write(&radio, 0x006U, (u8)delay) != AD9361_OK ||
                rf_capture_reset(0U) != 0 ||
                gpio_9361_init(&capture) != GPIO_9361_OK ||
                dma_9361_init(&receiver, &capture) != DMA_9361_OK)
                continue;
            bist_status = rf_rx_bist_selftest();
            rx_bist_scan_report.result[delay] = bist_status;
            rx_bist_scan_report.errors[delay] = rx_bist_report.period_errors;
            ++rx_bist_scan_report.tested;
            if (rx_bist_report.sample_count == 16384U &&
                rx_bist_report.period_errors < rx_bist_scan_report.best_errors) {
                rx_bist_scan_report.best_errors = rx_bist_report.period_errors;
                rx_bist_scan_report.best_delay = delay;
            }
        }
        /* A FRAME-only window is insufficient: keep a zero-error BIST
         * candidate only after repeating its complete DMA test. Otherwise
         * restore the FRAME-qualified setting selected before this scan. */
        if (rx_bist_scan_report.best_errors == 0U &&
            rx_bist_scan_report.result[rx_bist_scan_report.best_delay] == 0)
            selected_delay = rx_bist_scan_report.best_delay;
        if (rf_capture_reset(1U) == 0 &&
            ad9361_reg_write(&radio, 0x006U, (u8)selected_delay) == AD9361_OK &&
            rf_capture_reset(0U) == 0 && gpio_ris_init(&ris) == GPIO_RIS_OK &&
            gpio_9361_init(&capture) == GPIO_9361_OK &&
            dma_9361_init(&receiver, &capture) == DMA_9361_OK)
            bist_status = rf_rx_bist_selftest();
        else
            bist_status = DMA_9361_ERR_NOT_READY;
        xil_printf("RX BIST SCAN restored 006=%02x, final test=%d\r\n",
                   (unsigned)selected_delay, bist_status);
        dsb(); rx_bist_scan_report.done = 1U; dsb();
        xil_printf("RX BIST SCAN DONE: tested=%d best=%02x errors=%d\r\n",
                   (unsigned)rx_bist_scan_report.tested,
                   (unsigned)rx_bist_scan_report.best_delay,
                   (unsigned)rx_bist_scan_report.best_errors);
#else
        bist_status = rf_rx_bist_selftest();
#endif
    } else {
        rx_bist_report.magic = 0x52584254U;
        rx_bist_report.result = DMA_9361_ERR_NOT_READY;
        rx_bist_report.done = 1U;
        xil_printf("RX BIST SKIPPED: PLL/frame stability and MIG must pass before ARM; ARM=0\r\n");
        if (rf_config.ready)
            (void)ad_config_rx_bist_tone(&rf_config, 0U);
    }

    /* Each transaction already disables SPI and releases CS. Keep radio's
     * diagnostic fields available for inspection in the debugger.
     */
    /* Publish cached PS-DDR diagnostics for APU/JTAG memory inspection. */
    Xil_DCacheFlush();
    dsb();
    cleanup_platform();
    return status == AD9361_OK && ris_status == GPIO_RIS_OK &&
           capture_status == GPIO_9361_OK && dma_status == DMA_9361_OK &&
           mig_status == 0 &&
           config_status == AD_CONFIG_OK && clock_test_status == 0 &&
           rf_clock_test_report.frame_checks == 20U && bist_status == 0 ? 0 : 1;
}
