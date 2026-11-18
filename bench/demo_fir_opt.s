.text
.globl _start
_start:
  c.li s0, 2
  c.slli s0, 8
  c.li a4, 1
  c.slli a4, 31
  c.add s0, a4
  c.addi s0, 16
  c.mv s1, s0
  c.addi s1, 16
  c.li a2, 4
  c.jal .Lfir_opt
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
.globl fir_opt
.Lfir_opt:
  c.li a3, 0
  c.li a4, 0
  c.slt a4, a2
  c.beqz a4, .Lend
  c.slli a2, 2
  c.add a2, s1
.Lloop:
  c.lw a4, 0(s0)
  c.lw a5, 0(s1)
  c.addi s1, 4
  c.mul a4, a5
  c.add a3, a4
  c.addi s0, 4
  c.mv a4, s1
  c.xor a4, a2
  c.bnez a4, .Lloop
.Lend:
  c.mv a0, a3
  c.jr ra
