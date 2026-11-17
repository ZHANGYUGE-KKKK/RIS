#include "dma_diag.h"
#include "xil_printf.h"

u32 dma_diag_check(const u32 r[16], u32 next, u32 buffer, u32 index,
                  u32 bytes, u32 mask, u32 receiving)
{
    u32 issues = 0U;
    if (r[0] != next || r[1] != 0U) issues |= DMA_DIAG_NEXT;
    if (r[2] != buffer || r[3] != 0U) issues |= DMA_DIAG_BUFFER;
    if (r[13] != index) issues |= DMA_DIAG_ID;
    if ((r[6] & mask) != bytes || (r[6] & ~mask) != 0U)
        issues |= DMA_DIAG_CONTROL;
    if (receiving) {
        if ((r[7] & 0x8C000000U) != 0x8C000000U) issues |= DMA_DIAG_FLAGS;
        if ((r[7] & mask) != bytes) issues |= DMA_DIAG_LENGTH;
        if (r[7] & 0x70000000U) issues |= DMA_DIAG_HWERROR;
    } else if (r[7] != 0U) {
        issues |= DMA_DIAG_FLAGS;
    }
    return issues;
}

void dma_diag_print(const dma_diag_record *r, const char *tag)
{
    u32 i;
    xil_printf("RXDBG DMA %s: version=%u stage=%u result=%d issues=%03x index=%u BD=%08x checked=%u/%u/%u\r\n",
        tag, DMA_DIAG_VERSION, r->stage, r->result, r->issues, r->index,
        r->address, r->prepared_checked, r->submitted_checked, r->completed_checked);
    xil_printf("RXDBG DMA regs: CR=%08x SR=%08x CUR=%08x TAIL=%08x max_length=%u\r\n",
        r->control, r->status, r->current, r->tail, r->max_length);
    xil_printf("RXDBG BD: raw_status=%08x actual=%u control=%08x ID=%u BUF=%08x expected=%08x NEXT=%08x expected=%08x repeat_diff=%04x\r\n",
        r->raw[7], r->raw[7] & r->max_length, r->raw[6], r->raw[13],
        r->raw[2], r->expected_buffer, r->raw[0], r->expected_next, r->changed_words);
    if (!r->issues && r->result == 0) return;
    for (i = 0U; i < 16U; i += 4U)
        xil_printf("RXDBG BD words[%u]: %08x %08x %08x %08x; repeat: %08x %08x %08x %08x\r\n",
            i, r->raw[i], r->raw[i+1], r->raw[i+2], r->raw[i+3],
            r->repeat[i], r->repeat[i+1], r->repeat[i+2], r->repeat[i+3]);
    xil_printf("RXDBG issues: 001=SOF/EOF/complete 002=actual_length 004=ID 008=buffer 010=next 020=control_length 040=BD_hw_error\r\n");
}
