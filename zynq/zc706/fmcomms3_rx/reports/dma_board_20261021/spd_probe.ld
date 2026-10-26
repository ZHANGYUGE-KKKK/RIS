ENTRY(spd_probe)
SECTIONS {
 . = 0x30010000; .text : { *(.text*) *(.rodata*) }
 . = 0x30018000; .result : { *(.result) }
 /DISCARD/ : { *(.ARM.exidx*) *(.comment*) }
}
