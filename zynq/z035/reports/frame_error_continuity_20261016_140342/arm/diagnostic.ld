ENTRY(diag_run)
SECTIONS {
  . = 0x02000000;
  .text : { *(.text*) *(.rodata*) }
  .data : { *(.data*) }
  .bss : { *(.bss*) *(COMMON) }
  . = 0x02100000;
  .report (NOLOAD) : { *(.report) }
  /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
