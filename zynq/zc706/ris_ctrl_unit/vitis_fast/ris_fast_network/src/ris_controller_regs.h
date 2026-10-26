#ifndef RIS_CONTROLLER_REGS_H
#define RIS_CONTROLLER_REGS_H

/* Register offsets; BD assigns base 0x41200000. See ../README.txt. */
#define RIS_REG_ID                   0x0000u
#define RIS_REG_STATUS               0x0004u
#define RIS_REG_TX_STATE             0x0008u
#define RIS_REG_ERROR_FLAGS          0x000Cu
#define RIS_REG_OP_FLAGS             0x0010u
#define RIS_REG_CMD_ID               0x0014u
#define RIS_REG_ARG0                 0x0018u
#define RIS_REG_ARG1                 0x001Cu
#define RIS_REG_MASK_LO              0x0020u
#define RIS_REG_MASK_HI              0x0024u
#define RIS_REG_COMMIT               0x0028u
#define RIS_REG_LAST_ACCEPTED        0x002Cu
#define RIS_REG_RESULT_ID            0x0030u
#define RIS_REG_RESULT_CODE          0x0034u
#define RIS_REG_RESULT_POP           0x0038u
#define RIS_REG_QUEUE_LEVEL          0x003Cu
#define RIS_REG_CFG_PERIOD           0x0040u
#define RIS_REG_CFG_MASK_LO          0x0044u
#define RIS_REG_CFG_MASK_HI          0x0048u
#define RIS_REG_CFG_SEQ_BASE         0x004Cu
#define RIS_REG_CFG_SEQ_COUNT        0x0050u
#define RIS_REG_CFG_LOOP             0x0054u
#define RIS_REG_CFG_PREFILL          0x0058u
#define RIS_REG_CFG_HALF             0x005Cu
#define RIS_REG_CFG_GUARD            0x0060u
#define RIS_REG_CFG_LATCH            0x0064u
#define RIS_REG_CFG_RECOVERY         0x0068u
#define RIS_REG_FRAME_COUNT_LO       0x006Cu
#define RIS_REG_FRAME_COUNT_HI       0x0070u
#define RIS_REG_ERROR_FRAME_LO       0x0074u
#define RIS_REG_ERROR_FRAME_HI       0x0078u
#define RIS_REG_ACTIVE_PERIOD        0x007Cu
#define RIS_REG_SEQ_CURSOR           0x0080u
#define RIS_REG_ACTIVE_CMD_ID        0x0084u
#define RIS_REG_STREAM_FRAMES        0x0088u
#define RIS_REG_FRAME_SLOTS          0x008Cu
#define RIS_REG_RESET_EPOCH          0x0090u
#define RIS_REG_ACTIVE_MASK_LO       0x0094u
#define RIS_REG_ACTIVE_MASK_HI       0x0098u
#define RIS_REG_FAST_ID              0x00A0u
#define RIS_REG_FAST_CONTROL         0x00A4u
#define RIS_REG_FAST_STATUS          0x00A8u
#define RIS_REG_FAST_MHZ             0x00ACu
#define RIS_REG_FAST_EDGES           0x00B0u
#define RIS_REG_FAST_TICKS_CONFIG    0x00C0u
#define RIS_REG_FAST_TICKS_ACTIVE    0x00C4u
#define RIS_FAST_DEVICE_ID           0x46535432u
#define RIS_FAST_HALF_CLOCK_HZ       150000000u
#define RIS_FAST_MIN_TICKS           30u
#define RIS_FAST_MAX_TICKS           150000000u
#define RIS_FAST_LOCKED              1u
#define RIS_FAST_OWNED               2u
#define RIS_FAST_RUNNING             4u
#define RIS_FAST_LEVEL               8u
#define RIS_FAST_PENDING             16u
#define RIS_REG_STAGE                0x0100u
#define RIS_REG_IMAGE                0x0140u
#define RIS_REG_FRAME_RAM            0x1000u

#define RIS_OP_APPLY                 0x01u
#define RIS_OP_CLEAR_ALL             0x02u
#define RIS_OP_SET_MODE              0x10u
#define RIS_OP_CONFIG_APPLY          0x11u
#define RIS_OP_START                 0x20u
#define RIS_OP_PAUSE                 0x21u
#define RIS_OP_RESUME                0x22u
#define RIS_OP_STOP_HOLD             0x23u
#define RIS_OP_OUTPUT_ENABLE         0x30u
#define RIS_OP_OUTPUT_DISABLE        0x31u
#define RIS_OP_PUBLISH_BLOCK         0x40u
#define RIS_OP_FLUSH_DATA            0x41u
#define RIS_OP_CLEAR_ERROR           0x50u
#define RIS_OP_SOFT_RESET            0x7Fu

#define RIS_FLAG_APPLY_HOLD        (1u << 8)
#define RIS_FLAG_APPLY_ONCE        (2u << 8)
#define RIS_FLAG_PUBLISH_STREAM    (1u << 8)
#define RIS_RESULT_DONE            1u
#define RIS_RESULT_REJECTED        2u
#define RIS_RESULT_CANCELLED       3u
#define RIS_RESULT_FAILED          4u
#define RIS_FRAME_STRIDE           64u
#define RIS_FRAME_BYTES            50u

#endif
