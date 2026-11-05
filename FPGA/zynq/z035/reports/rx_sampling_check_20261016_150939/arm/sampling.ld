ENTRY(sampling_entry)
SECTIONS {
  . = 0x02200000;
  .text : { *(.text*) *(.rodata*) }
  .data : { *(.data*) }
  .bss : { *(.bss*) *(COMMON) }
  . = 0x02300000; .header (NOLOAD) : { *(.header) }
  . = 0x02301000; .spi (NOLOAD) : { *(.spi) }
  . = 0x02302000; .rows (NOLOAD) : { *(.rows) }
  /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
