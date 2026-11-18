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
