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
.text
.p2align 1
.Lsum:
  c.li a2, 0
  c.li a4, 0
  c.slt a4, a1
  c.beqz a4, .LBB0_3
  c.slli a1, 2
  c.add a1, a0
.LBB0_2:
  c.mv s0, a0
  c.lw a3, 0(s0)
  c.addi a0, 4
  c.add a2, a3
  c.mv a4, a0
  c.xor a4, a1
  c.bnez a4, .LBB0_2
.LBB0_3:
  c.mv a0, a2
  c.jr ra
.Lfunc_end0:
