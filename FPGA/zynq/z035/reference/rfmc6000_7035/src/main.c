/***************************************************************************//**
 *   @file   main.c
 *   @brief  Implementation of Main Function.
 *   @author DBogdan (dragos.bogdan@analog.com)
 ********************************************************************************
 * Copyright 2013(c) Analog Devices, Inc.
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *  - Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  - Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *  - Neither the name of Analog Devices, Inc. nor the names of its
 *    contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *  - The use of this software may or may not infringe the patent rights
 *    of one or more patent holders.  This license does not release you
 *    from the requirement that you obtain separate licenses from these
 *    patent holders to use this software.
 *  - Use of the software either in source or binary form, must be run
 *    on or directly connected to an Analog Devices Inc. component.
 *
 * THIS SOFTWARE IS PROVIDED BY ANALOG DEVICES "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, NON-INFRINGEMENT,
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL ANALOG DEVICES BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, INTELLECTUAL PROPERTY RIGHTS, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*******************************************************************************/

/******************************************************************************/
/***************************** Include Files **********************************/
/******************************************************************************/
#include <stdlib.h>
#include <stdio.h>
#include "config.h"
#include "ad9361_api.h"
#include "parameters.h"
#include "platform.h"
#include <xil_cache.h>
#include "spi_ctrl.h"
#include "io_control.h"
#include "gpio_initial.h"
#include "radio_set.h"
#include "ad9361_config.h"
#include "xtime_l.h"
#include "xadc.h"
/******************************************************************************/
/************************ Variables Definitions *******************************/
/******************************************************************************/
uint32_t axi_lite_addr = XPAR_AXI_LITEV3_0_BASEADDR;
uint32_t fpga_ver=0xa4;
uint32_t sw_ver=0xa2;
uint32_t config_done=0;
uint32_t sample_rate = 61.44e6;
uint64_t tx_lo_freq = 5997e6;
uint64_t rx_lo_freq = 200e6;
uint32_t bandwidth = 30.72e6;
int32_t gain = 5;
uint32_t txatt = 0e3;
uint32_t regr = REG_PRODUCT_ID;
int32_t tempa;
struct ad9361_rf_phy *ad9361_phy;
struct ad9361_rf_phy *ad9361_phy_b;
struct spi_device cdcm6208_spi = { .id_no = 0, };
uint8_t fastlocklist[16][16]={0};
void set_fastlock_list();
void start_freq_hopping();

/***************************************************************************//**
 * @brief main
 *******************************************************************************/
int main(void) {
//	Xil_ICacheDisable();
//	Xil_DCacheDisable();
	Xil_ICacheEnable();
	Xil_DCacheEnable();
	print("**************************************************\n\r");
	print("**********Y420S trxloop standalone begin**********\n\r");
	print("**************************************************\n\r");
	// NOTE: The user has to choose the GPIO numbers according to desired
	// carrier board.
	gpio_initial();
	spi_init(SPI_DEVICE_ID1, 0, 0);
	cdcm6208_init(&cdcm6208_spi);
	cdcm6208_y5_internal(&cdcm6208_spi);
	uint32_t lock_rf1=-1;
	while (lock_rf1 != 0) {
		lock_rf1 = cdcm6208_spi_read(&cdcm6208_spi, 21) & 0xF;
		printf("read from CDCM6208_RF1 reg21=0x%lx\n", lock_rf1);
	}
	printf("read from CDCM6208_RF1 reg21=0x%lx\n", lock_rf1);
	mdelay(10);
	gpio_set_value(CDCM_SYNC, 1);
	mdelay(10);
	gpio_set_value(CDCM_SYNC, 0);
	mdelay(10);
	gpio_set_value(CDCM_SYNC, 1);
	mdelay(500);
//configure RF1
	default_init_param.gpio_resetb = RF1_RESETB;
	default_init_param.gpio_sync = -1;
	default_init_param.gpio_cal_sw1 = -1;
	default_init_param.gpio_cal_sw2 = -1;
	spi_init(SPI_DEVICE_ID, 1, 0);
	ad9361_init(&ad9361_phy, &default_init_param);
	ad9361_spi_write(ad9361_phy->spi, REG_TX_CLOCK_DATA_DELAY, 0x40);
	int32_t val;
	val=ad9361_config(ad9361_phy);
	printf("ad9361_phy,REG_PRODUCT_ID=%ld\n\r", val);
//set yunsdr axi lite
	uint32_t val_out = AXI_REG_READ(axi_lite_addr, 0);
	printf("register addr=0x0 read out = %ld\n\r", val_out & 0xFFFF);
	printf("The FPGA firmware version=V1.0\n");
	printf("The Software firmware version=V1.0\n");
	printf("The lasted build at 20201111_PM1\n");
	printf("The lasted build at %s %s\n", __TIME__, __DATE__);
//	set_fastlock_list();
	//set yunsdr axi lite
	AXI_REG_WRITE(axi_lite_addr, 2 * 4, 0);				//pps_disable
	AXI_REG_WRITE(axi_lite_addr, 3 * 4, 256);			//phase
	AXI_REG_WRITE(axi_lite_addr, 4 * 4, 1);				//rf_mode
	AXI_REG_WRITE(axi_lite_addr, 5 * 4, sample_rate<<2);//clock_1pps
	AXI_REG_WRITE(axi_lite_addr, 21 * 4, 0x7F);			//idelay_sel
	AXI_REG_WRITE(axi_lite_addr, 22 * 4, 12);			//idelay
	val = xadc_initial(XPAR_PS7_XADC_0_DEVICE_ID);
	if (val == 0) {
		printf("Xadc Setup PASSED\r\n");
	}
//	int i=0;
//	for(i=0;i<10000;i++){
//		//spi ctrl;
//		start_freq_hopping();
//		//pin_ctrl
//		//start_pin_ctrl_freq_hopping();
//	}

	spi_init(SPI_DEVICE_ID1, 0, 0);
	val = cdcm6208_spi_read(&cdcm6208_spi, 21) & 0xF;
	if (val == 0)
		printf("CDCM6208 use internal 10MHz VCTCXO lock successful!\n");
	else if (val == 1)
		printf("CDCM6208 use external 10MHz VCTCXO lock successful!\n");
	else
		printf("Warning:CDCM6208 failed!\n");
	printf("Y420S initial successful!\n");
	AXI_REG_WRITE(axi_lite_addr, 1 * 4, 1);				//mtime_start
#if 0
	xil_printf("0x0A7:%x\n\r",ad9361_spi_read(ad9361_phy->spi,0x0A7));
	xil_printf("0x0A8:%x\n\r",ad9361_spi_read(ad9361_phy->spi,0x0A8));
	ad9361_spi_write(ad9361_phy->spi,0x0A0,0x020);
	ad9361_spi_write(ad9361_phy->spi,0x0A3,0x040);//确保0x0A0[6:5]和0x0A3[7:6]相同
	xil_printf("0x0A0:%x\n\r",ad9361_spi_read(ad9361_phy->spi,0x0A0));
	xil_printf("0x0A3:%x\n\r",ad9361_spi_read(ad9361_phy->spi,0x0A3));
	ad9361_spi_write(ad9361_phy->spi,0x0a5,0x001);
	ad9361_spi_write(ad9361_phy->spi,0x0a6,0x001);//门限
	ad9361_spi_write(ad9361_phy->spi,0x014,0x003);//MovefromTxRXtoALERT
	ad9361_spi_write(ad9361_phy->spi,0x0169,0x0FC&ad9361_spi_read(ad9361_phy->spi,0x169));//0x169[1:0]=0
	ad9361_spi_write(ad9361_phy->spi,0x018b,0x0D7&ad9361_spi_read(ad9361_phy->spi,0x18b));//0x18b[5]=0,0x18b[3]=0
	ad9361_spi_write(ad9361_phy->spi,REG_QUAD_CAL_NCO_FREQ_PHASE_OFFSET,RX_NCO_FREQ(1) | RX_NCO_PHASE_OFFSET(28));//0x0A0[4:0]=0x3CRxNCOPHASEOffset
	xil_printf("0x0A0:%x\n\r",ad9361_spi_read(ad9361_phy->spi,0x0A0));
	ad9361_spi_write(ad9361_phy->spi,0x016,0x010);//StartTxQuadcal
	mdelay(20);
	xil_printf("ModifytheRxNCOphaseoffsetandTriggerTxQECCAL---0x0A7:%x\n\r",ad9361_spi_read(ad9361_phy->spi,0x0A7));
	xil_printf("ModifytheRxNCOphaseoffsetandTriggerTxQECCAL---0x0A8:%x\n\r",ad9361_spi_read(ad9361_phy->spi,0x0A8));
	ad9361_spi_write(ad9361_phy->spi,0x014,0x023);//MovefromAlerttoTXRX
//	ad9361_spi_write(ad9361_phy->spi,REG_LO_CM,0);
#endif



	float temp;
	xadc_read_temp(&temp);
	printf("fpga temperature=%lf\n",temp);
	spi_init(SPI_DEVICE_ID, 1, 0);
	tempa=ad9361_get_temp(ad9361_phy);
	printf("rf1_ad9361 temp=%ld,\n", tempa);
	XTime tEnd, tCur;
	int time_flag = 0;
	while (1) {
		if (!time_flag) {
			XTime_GetTime(&tCur);
			time_flag = 1;
		} else {
			XTime_GetTime(&tEnd);
			if ((tEnd - tCur) >= COUNTS_PER_SECOND) {
				xadc_read_temp(&temp);
				printf("\nfpga temp=%2.1f", temp);
				tempa = ad9361_get_temp(ad9361_phy);
				printf(",%ld", tempa);
				time_flag = 0;
			}
		}
	}
}


void set_fastlock_list(){
	int i=0;
	for(i=0;i<16;i++){
		if(i<8){ //first 8 profile save to ad9361 and local list
			//calib lo
			ad9361_set_tx_lo_freq(ad9361_phy, tx_lo_freq+(i*200e3));
			//store freq parameter to profile
			ad9361_tx_fastlock_store(ad9361_phy,(uint32_t)i);
			//read back to user array
			ad9361_tx_fastlock_save(ad9361_phy,i,(uint8_t*)&fastlocklist[i][0]);
		}
		else {
			//calib lo
			ad9361_set_tx_lo_freq(ad9361_phy, tx_lo_freq+(i*200e3));
			//store freq parameter to profile
			ad9361_tx_fastlock_store(ad9361_phy,(uint32_t)(i-8));
			//read back to user array
			ad9361_tx_fastlock_save(ad9361_phy,i,(uint8_t*)&fastlocklist[i][0]);
		}
	}
	for(i=0;i<8;i++){
		ad9361_tx_fastlock_load(ad9361_phy,i,(uint8_t*)&fastlocklist[i][0]);
	}

//	ad9361_set_tx_lo_freq(ad9361_phy, tx_lo_freq);

}


void start_freq_hopping(){
	uint8_t i=0,j=0;
	for(i=0;i<16;i++){
		if(i<8){
			ad9361_tx_fastlock_recall(ad9361_phy,i);
			usleep(500000);
		}
		else {
			if(i==8){//load new list 8~15
				for(j=0;j<8;j++){
					ad9361_tx_fastlock_load(ad9361_phy,j,(uint8_t*)&fastlocklist[j+8][0]);
				}
				//hopping
				ad9361_tx_fastlock_recall(ad9361_phy,i-8);
				usleep(500000);
			}
			else {
				//hopping
				ad9361_tx_fastlock_recall(ad9361_phy,i-8);
				usleep(500000);
			}
		}

	}
//reset to 0~7profile
	for(j=0;j<8;j++){
		ad9361_tx_fastlock_load(ad9361_phy,j,(uint8_t*)&fastlocklist[j][0]);
	}

}
