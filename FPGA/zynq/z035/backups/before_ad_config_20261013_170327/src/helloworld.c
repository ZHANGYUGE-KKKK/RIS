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
#include "xparameters.h"
#include "xpseudo_asm.h"
#include "xtime_l.h"
#include <string.h>

static ad9361_device radio;
static gpio_ris_device ris;
static gpio_9361_device capture;
static dma_9361_device receiver;

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

int main()
{
    int status;
    int ris_status;
    int capture_status;
    int dma_status;
    int mig_status;

    init_platform();
    ris_status = gpio_ris_init(&ris);
    if (ris_status == GPIO_RIS_OK) {
        xil_printf("\r\nRIS AXI GPIO @0x%08x: MONITOR, command=0x%08x\r\n",
                   (unsigned int)XPAR_AXI_GPIO_RIS_CTL_BASEADDR,
                   (unsigned int)ris.last_command);
    } else {
        xil_printf("\r\nRIS GPIO INIT FAILED (%d): %s\r\n", ris_status,
                   gpio_ris_status_string(ris_status));
    }
    xil_printf("\r\nRFMC6000 AD9361 SPI bring-up\r\n");
    xil_printf("SPI0 EMIO, SS0, mode 1; checking connectivity\r\n");
    xil_printf("RESETB: EMIO[%d], PS GPIO pin %d, FPGA T29\r\n",
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

    capture_status = gpio_9361_init(&capture);
    if (capture_status == GPIO_9361_OK) {
        xil_printf("\r\nCAPTURE GPIO @0x%08x: ARM command=0, status=0x%02x\r\n",
                   (unsigned int)XPAR_AXI_GPIO_9361_BASEADDR,
                   (unsigned int)capture.last_status);
    } else {
        xil_printf("\r\nCAPTURE GPIO INIT FAILED (%d): %s\r\n",
                   capture_status, gpio_9361_status_string(capture_status));
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

    /* Each transaction already disables SPI and releases CS. Keep radio's
     * diagnostic fields available for inspection in the debugger.
     */
    cleanup_platform();
    return status == AD9361_OK && ris_status == GPIO_RIS_OK &&
           capture_status == GPIO_9361_OK && dma_status == DMA_9361_OK &&
           mig_status == 0 ? 0 : 1;
}
