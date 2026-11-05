ENTRY(trial_entry)
SECTIONS {
  . = 0x02600000;
  .text : { *(.text*) *(.rodata*) }
  .data : { *(.data*) }
  .bss : { *(.bss*) *(COMMON) }
  . = 0x02700000; .header (NOLOAD) : { *(.header) }
  . = 0x02701000; .spi (NOLOAD) : { *(.spi) }
  . = 0x02702000; .rows (NOLOAD) : { *(.rows) }
  /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
