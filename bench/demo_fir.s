.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.mv a0, s0
  c.addi a0, 16
  c.mv a1, a0
  c.addi a1, 16
  c.li a2, 4
  c.jal .Lfir
  c.li a5, 1
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
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
x:
  .word 1, 2, 3, 4
h:
  .word 5, 6, 7, 8
.text
.p2align 1
.Lfir:
  c.li a3, 0
  c.li a4, 0
  c.slt a4, a2
  c.beqz a4, .LBB0_3
  c.slli a2, 2
  c.add a2, a1
.LBB0_2:
  c.mv s0, a0
  c.lw a4, 0(s0)
  c.mv s0, a1
  c.lw a5, 0(s0)
  c.addi a1, 4
  c.mul a4, a5
  c.add a3, a4
  c.addi a0, 4
  c.mv a4, a1
  c.xor a4, a2
  c.bnez a4, .LBB0_2
.LBB0_3:
  c.mv a0, a3
  c.jr ra
.Lfunc_end0:
