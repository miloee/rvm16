ENTRY(_start)
SECTIONS {
  . = 0x80000000;
  .scratch (NOLOAD) : { . += 0x100; }
  . = 0x80000100;
  .text : { *(.text) }
  . = 0x80000200;
  .data : { *(.data) *(.sdata) *(.rodata) }
}
