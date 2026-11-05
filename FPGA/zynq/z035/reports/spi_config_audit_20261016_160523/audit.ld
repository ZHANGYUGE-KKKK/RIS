ENTRY(audit_entry)
SECTIONS {
  . = 0x02400000;
  .text : { *(.text*) *(.rodata*) }
  .data : { *(.data*) }
  .bss : { *(.bss*) *(COMMON) }
  . = 0x02500000; .header (NOLOAD) : { *(.header) }
  . = 0x02501000; .spi (NOLOAD) : { *(.spi) }
  . = 0x02502000; .rows (NOLOAD) : { *(.rows) }
  /DISCARD/ : { *(.ARM.exidx*) *(.ARM.extab*) }
}
