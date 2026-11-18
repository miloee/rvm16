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
