.text
.globl _start
_start:
  c.li sp, 1
  c.slli sp, 31
  c.addi sp, 16
  c.li a0, 3
  c.li a1, 4
  c.jal .Lf
  c.li a5, 1
  c.li a4, 1
  c.slli a4, 31
  c.li s0, 2
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
.text
.p2align 1
.Ladd:
  c.add a0, a1
  c.jr ra
.Lfunc_end0:
.Lf:
  c.addi sp, -16
  c.sw ra, 3(sp)
  c.jal .Ladd
  c.slli a0, 1
  c.lw ra, 3(sp)
  c.addi sp, 16
  c.jr ra
.Lfunc_end1:
