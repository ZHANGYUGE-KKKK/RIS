#ifndef RIS_PROTOCOL_H
#define RIS_PROTOCOL_H
#include "ris_controller.h"
#include <stddef.h>
/* Returns 1 when a blink command restarts the period, otherwise 0. */
int ris_protocol_execute(ris_controller *dev,char *line,char *reply,size_t capacity,u32 *blink_ms);
#endif
