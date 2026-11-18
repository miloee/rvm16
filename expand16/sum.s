	.attribute	4, 16
	.attribute	5, "rv32i2p1_m2p0_a2p1_f2p2_c2p0_zicsr2p0_zmmul1p0_zaamo1p0_zalrsc1p0_zca1p0_zcf1p0"
	.file	"sum.c"
	.text
	.globl	sum                             # -- Begin function sum
	.p2align	1
	.type	sum,@function
sum:                                    # @sum
# %bb.0:
	li	a2, 0
	blez	a1, .LBB0_3
# %bb.1:
	slli	a1, a1, 2
	add	a1, a1, a0
.LBB0_2:                                # =>This Inner Loop Header: Depth=1
	lw	a3, 0(a0)
	addi	a0, a0, 4
	add	a2, a2, a3
	bne	a0, a1, .LBB0_2
.LBB0_3:
	mv	a0, a2
	ret
.Lfunc_end0:
	.size	sum, .Lfunc_end0-sum
                                        # -- End function
	.ident	"clang version 23.0.0git (https://gitee.com/mirrors/llvm-project.git 1456e9b2eb412eb9a6f089c9bbd3e524a68eb5bb)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
