ENTRY(_start)
SECTIONS {
  . = 0x80000000;
  .text : { *(.text.start) *(.text*) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) }
  .bss : { *(.bss*) *(COMMON) }
  . = ALIGN(16);
  _heap_start = .;
  . = . + 0x40000;
  _heap_end = .;
  . = ALIGN(16);
  _stack_top = . + 0x4000;
}
