.text
.globl sum_opt
sum_opt:
  c.li a2, 0
  c.li a4, 0
  c.slt a4, a1
  c.beqz a4, .Lend
  c.slli a1, 2
  c.add a1, s0
.Lloop:
  c.lw a3, 0(s0)
  c.addi s0, 4
  c.add a2, a3
  c.mv a4, s0
  c.xor a4, a1
  c.bnez a4, .Lloop
.Lend:
  c.mv a0, a2
  c.jr ra
