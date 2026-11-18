.text
.globl _start
_start:
  c.li sp, 2
  c.slli sp, 5
  c.slli sp, 5
  c.slli sp, 5
  c.slli sp, 5
  c.slli sp, 5
  c.addi sp, 24
  c.slli sp, 5
  c.li a0, 3
  c.li a1, 4
  c.jal .Lf
  c.li a5, 1
  c.li a4, 1
  c.slli a4, 31
  c.li s0, 1
  c.slli s0, 8
  c.add s0, a4
  c.sw a5, 0(s0)
1:
  c.j 1b
.data
.globl tohost
.align 3
tohost:
  .zero 8
.globl fromhost
fromhost:
  .zero 8
  .space 0x200
