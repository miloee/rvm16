SECTIONS
{
  . = 0x80000000;
  .text : { *(.text) }
  . = 0x80000100;
  .data : { *(.data) }
}
