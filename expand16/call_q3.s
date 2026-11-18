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
