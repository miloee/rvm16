.text
.globl _start
_start:
  c.li s0, 1
  c.slli s0, 31
  c.li a4, 1
  c.slli a4, 8
  c.add s0, a4
  c.mv a0, s0
  c.addi a0, 16
  c.li a1, 4
  c.jal .Lsum
  c.li a5, 1
  c.li s0, 1
  c.slli s0, 31
  c.li a4, 1
  c.slli a4, 8
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
array:
  .word 1, 2, 3, 4
