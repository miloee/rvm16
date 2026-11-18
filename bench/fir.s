	.attribute	4, 16
	.attribute	5, "rv32i2p1_m2p0_a2p1_f2p2_c2p0_zicsr2p0_zmmul1p0_zaamo1p0_zalrsc1p0_zca1p0_zcf1p0"
	.file	"fir.c"
	.text
	.globl	fir                             # -- Begin function fir
	.p2align	1
	.type	fir,@function
fir:                                    # @fir
# %bb.0:
	li	a3, 0
	blez	a2, .LBB0_3
# %bb.1:
	slli	a2, a2, 2
	add	a2, a2, a1
.LBB0_2:                                # =>This Inner Loop Header: Depth=1
	lw	a4, 0(a0)
	lw	a5, 0(a1)
	addi	a1, a1, 4
	mul	a4, a5, a4
	add	a3, a3, a4
	addi	a0, a0, 4
	bne	a1, a2, .LBB0_2
.LBB0_3:
	mv	a0, a3
	ret
.Lfunc_end0:
	.size	fir, .Lfunc_end0-fir
                                        # -- End function
	.ident	"clang version 23.0.0git (https://gitee.com/mirrors/llvm-project.git 1456e9b2eb412eb9a6f089c9bbd3e524a68eb5bb)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
