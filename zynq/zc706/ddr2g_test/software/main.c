#include "xparameters.h"
#include "xil_io.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xuartps.h"
#include "xtime_l.h"
#include "sleep.h"

#define CONTROL 0x41200000U
#define ERRORS  0x41210000U
#define VALUES  0x41220000U
#define BUSY 1U
#define DONE 2U
#define BAD 4U
#define READY 8U
#define BUS_ERROR 0x100U
static u32 command_toggle;
static XUartPs uart;
static const char *patterns[] = {"ZERO", "ONES", "AA55", "ADDRESS_XOR", "INVERSE_ADDRESS_XOR"};

static u32 status_read(void) { return Xil_In32(CONTROL+8U); }
static unsigned elapsed_ms(XTime start)
{
    XTime now; XTime_GetTime(&now);
    return (unsigned)(((now-start)*1000ULL)/COUNTS_PER_SECOND);
}
static void status_print(void)
{
    u32 s=status_read();
    xil_printf("DDR STATUS=%08x ready=%u calib=%u mmcm=%u ui_reset=%u busy=%u done=%u state=%u\r\n",
        s,!!(s&READY),(s>>9)&1U,(s>>10)&1U,(s>>11)&1U,!!(s&BUSY),!!(s&DONE),(s>>12)&15U);
    xil_printf("DDR RESULT error_words=%u first_offset=%08x expected=%08x actual=%08x bus_error=%u\r\n",
        Xil_In32(ERRORS+8U),Xil_In32(ERRORS),Xil_In32(VALUES),Xil_In32(VALUES+8U),!!(s&BUS_ERROR));
}
static int test_pass(unsigned mode,unsigned quick,unsigned upper)
{
    u32 s=status_read(),cmd;
    XTime start; unsigned last_report=0,ms;
    if ((s>>28)!=0xAU || !(s&READY) || (s&BUSY)) {
        xil_printf("DDR REFUSED: engine not ready or still busy. No test started.\r\n");
        status_print(); return -1;
    }
    command_toggle^=1U;
    cmd=command_toggle|(mode<<1)|(quick<<4)|(upper<<5);
    xil_printf("DDR BEGIN pattern=%s bytes=%u start=%08x end=%08x\r\n",patterns[mode],
        quick?0x00800000U:0x80000000U,quick&&upper?0x40000000U:0U,
        quick?(upper?0x407fffffU:0x007fffffU):0x7fffffffU);
    XTime_GetTime(&start);
    Xil_Out32(CONTROL,cmd);
    // Require BUSY before accepting DONE, so stale completion cannot pass a new test.
    do {
        s=status_read();
        if (elapsed_ms(start)>1000U) {
            xil_printf("DDR FAIL: command acceptance timeout.\r\n");status_print();return -1;
        }
    } while (!(s&BUSY) || ((s>>27)&1U)!=command_toggle);
    for (;;) {
        s=status_read();ms=elapsed_ms(start);
        if ((s&DONE) && !(s&BUSY)) break;
        if (ms-last_report>=1000U) {
            last_report=ms;
            xil_printf("DDR PROGRESS elapsed_ms=%u phase=%s offset_MiB=%u state=%u error_words=%u\r\n",
                ms,(s&0x80U)?"READ":"WRITE",(s>>16)&2047U,(s>>12)&15U,Xil_In32(ERRORS+8U));
        }
        if (ms>300000U || !(s&READY)) {
            xil_printf("DDR FAIL: timeout or calibration/clock lost. Hardware transaction is not forcibly aborted.\r\n");
            status_print();return -1;
        }
        usleep(1000);
    }
    // Diagnostic record is held stable by the engine until the next command.
    usleep(10);
    status_print();
    if ((s&BAD) || Xil_In32(ERRORS+8U)!=0U || ((s>>27)&1U)!=command_toggle) {
        xil_printf("DDR TEST FAIL pattern=%s elapsed_ms=%u\r\n",patterns[mode],ms);return -1;
    }
    xil_printf("DDR TEST PASS pattern=%s bytes=%u elapsed_ms=%u\r\n",patterns[mode],
        quick?0x00800000U:0x80000000U,ms);
    return 0;
}
static void suite(unsigned quick,unsigned upper)
{
    unsigned i,failed=0,completed=0;
    for (i=0;i<5;i++) {
        if (test_pass(i,quick,upper)) failed++;
        completed++;
        if (status_read()&BUSY) break;
    }
    xil_printf("DDR SUITE %s completed=%u/5 failed=%u\r\n",(!failed&&completed==5)?"PASS":"FAIL",completed,failed);
}
static void menu(void)
{
    xil_printf("\r\nDDR2G MENU (single ASCII character, no newline required):\r\n");
    xil_printf("  s=status; 0=lower 8MiB, 5 patterns; 1=upper 8MiB, 5 patterns\r\n");
    xil_printf("  f=FULL 2GiB address pattern (rank/address alias check)\r\n");
    xil_printf("  a=FULL 2GiB, all 5 patterns; h=help\r\n");
    xil_printf("Full tests overwrite PL DDR only; program and stack stay in PS DDR.\r\n> ");
}
int main(void)
{
    XUartPs_Config *cfg=XUartPs_LookupConfig(XPAR_XUARTPS_0_DEVICE_ID);
    if (!cfg || XUartPs_CfgInitialize(&uart,cfg,cfg->BaseAddress)!=XST_SUCCESS) return 1;
    XUartPs_SetBaudRate(&uart,115200);
    Xil_ICacheEnable();Xil_DCacheEnable();
    xil_printf("\r\nZC706 DDR2G STANDALONE BIST v1, built %s %s\r\n",__DATE__,__TIME__);
    xil_printf("Target DIMM: Micron MT16JSF25664HZ-1G4F1, 2GiB, 2Rx8, x64, 1.5V\r\n");
    xil_printf("MIG: DDR3-1333, CK=666.667MHz, UI=166.667MHz, CL9/CWL7, row14/col10/bank3\r\n");
    xil_printf("PL AXI master: 512-bit, full strobes, one outstanding transaction, local 00000000..7FFFFFFF\r\n");
    xil_printf("No RF, DMA or Ethernet initialization. Tests start only on a menu command.\r\n");
    command_toggle=0;Xil_Out32(CONTROL,0);
    usleep(100000);
    status_print();menu();
    for (;;) {
        unsigned char c=XUartPs_RecvByte(cfg->BaseAddress);
        if (c=='\r'||c=='\n'||c==' ') continue;
        xil_printf("%c\r\n",c);
        switch(c) {
        case 's':status_print();break;
        case '0':suite(1,0);break;
        case '1':suite(1,1);break;
        case 'f':test_pass(3,0,0);break;
        case 'a':suite(0,0);break;
        case 'h':menu();continue;
        default:xil_printf("Unknown command. h=help.\r\n");break;
        }
        xil_printf("> ");
    }
}
