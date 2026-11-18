# Expand16 prototype: C -> Q3

This is a standalone translator, not the LLVM post-RA pass.  It takes the
RV32 assembly emitted by clang for a leaf function and expands the subset into
Q3/RVC 16-bit instructions.  It proves the C -> Q3 path while the LLVM pass is
being written.

## C source

    int f(int a, int b) {
      return (a << b) + (a * b) - (a < b);
    }

clang -O2 emits:

    sll a2, a0, a1
    mul a3, a1, a0
    add a2, a2, a3
    slt a0, a0, a1
    sub a0, a2, a0
    ret

All registers are a0-a3 (x10-x13), inside the RVC x8-x15 window.

## Expansion

    c.mv a2, a0        # sll is 2-address
    c.sll a2, a1
    c.mv a3, a1        # mul is 2-address
    c.mul a3, a0       # Zcb c.mul
    c.add a2, a3
    c.slt a0, a1
    c.mv a4, a0        # save (a<b)
    c.mv a0, a2
    c.sub a0, a4
    c.jr ra

## Build and run

    B=/home/milo/rvv-alt/llvm-project/build/bin
    $B/clang --target=riscv32 -march=rv32imafc -O2 -S -o ctest.s ctest.c
    python3 tools/expand16.py < ctest.s > f_q3.s
    cat expand16/harness.s f_q3.s > demo16.s
    $B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb,+zc16q3 -filetype=obj -o demo16.o demo16.s
    riscv64-linux-gnu-ld -m elf32lriscv -T bench/link.ld -o demo16.elf demo16.o
    /home/milo/spike-q3/build/spike --isa=RV32IMC_Zcb_Zc16 --pc=0x80000000 --log-commits demo16.elf

## Result

    RC=0
    0x80000004 (0x2809) x1  0x80000006     # c.jal .Lf
    0x80000020 (0x352f) x10 0x00000001    # c.slt
    0x80000026 (0x8d19) x10 0x0000003b    # c.sub -> 59
    0x80000028 (0x8082)                    # c.jr ra
    0x80000006 (0x4405) x8  0x00000001    # back in harness

f(3,4) = (3<<4) + (3*4) - (3<4) = 48 + 12 - 1 = 59.

## Limits

- leaf functions only; no calls/branches/loads/stores yet;
- all values must be in x8-x15 (s0/s1/a0-a5); the Q3/RVC forms cannot encode
  x16-x31 for add/sub/mv;
- sub with rd != rs1 needs a free temp;
- the assembler may relax c.jal to a 32-bit JAL for global targets; use a
  local .Lf label to force C.JAL.
