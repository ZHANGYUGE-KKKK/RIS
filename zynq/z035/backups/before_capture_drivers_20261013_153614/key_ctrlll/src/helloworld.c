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
#include "xparameters.h"

static ad9361_device radio;
static gpio_ris_device ris;

int main()
{
    int status;
    int ris_status;

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

    /* Each transaction already disables SPI and releases CS. Keep radio's
     * diagnostic fields available for inspection in the debugger.
     */
    cleanup_platform();
    return status == AD9361_OK && ris_status == GPIO_RIS_OK ? 0 : 1;
}
