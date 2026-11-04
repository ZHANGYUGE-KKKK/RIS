#ifndef RIS_QAM_REGS_H
#define RIS_QAM_REGS_H
/* QAM1 additive AXI ABI. Offsets relative to the existing RIS peripheral.
 * This header defines registers only, not a UART/TCP transport or driver.
 */
#define RIS_QAM_ID             0x0200u
#define RIS_QAM_CONTROL        0x0204u
#define RIS_QAM_SLOT_TICKS     0x0208u
#define RIS_QAM_REPEATS        0x020cu
#define RIS_QAM_PERIOD_SLOTS   0x0210u
#define RIS_QAM_STATUS         0x0214u
#define RIS_QAM_ERROR          0x0218u
#define RIS_QAM_MIN_TICKS      0x021cu
#define RIS_QAM_FRAME_COUNT    0x0220u /* bank[15:12], complete frames[11:0] */
#define RIS_QAM_EVENT_COUNT    0x0224u
#define RIS_QAM_SYMBOL_COUNT   0x0228u
#define RIS_QAM_PAYLOAD_COUNT  0x022cu
#define RIS_QAM_FRAME_CAPACITY 0x0230u
#define RIS_QAM_EVENT_CAPACITY 0x0234u
#define RIS_QAM_BYTE_CAPACITY  0x0238u
#define RIS_QAM_CLOCK_HZ       0x023cu
#define RIS_QAM_FRAME_DATA     0x0240u /* 13 LE words/frame, word12[31:16]=0 */
#define RIS_QAM_EVENT_DATA     0x0244u /* slots[31:16], frame_id[15:0] */
#define RIS_QAM_SYMBOL_DATA    0x0248u /* count[31:16], first_event[15:0] */
#define RIS_QAM_PAYLOAD_DATA   0x024cu /* one byte in low 8 bits per write */
#define RIS_QAM_HELD_FRAME     0x0280u /* 13 RO words, only coherent when idle */
#define RIS_QAM_ID_VALUE       0x51414d31u
#define RIS_QAM_STOP           0u
#define RIS_QAM_ONCE           1u
#define RIS_QAM_LOOP           2u
#define RIS_QAM_RELEASE        8u
#define RIS_QAM_CLEAR_UPLOAD   16u
#define RIS_QAM_OWNED          (1u << 0)
#define RIS_QAM_RUNNING        (1u << 1)
#define RIS_QAM_PREFLIGHT      (1u << 2)
#define RIS_QAM_PENDING        (1u << 3)
#define RIS_QAM_FAILED         (1u << 4)
#define RIS_QAM_ERROR_NONE     0u
#define RIS_QAM_ERROR_SYMBOL   1u
#define RIS_QAM_ERROR_EVENT    2u
#define RIS_QAM_ERROR_PERIOD   3u
#define RIS_QAM_ERROR_UNDERRUN 4u
#endif
