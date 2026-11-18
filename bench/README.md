# Benchmarks

Small hand-written kernels used in the Zhihu article.  These are **not** a
C benchmark suite; the Expand16 compiler pass is still missing.

## Files

| File | ISA | What it does |
|---|---|---|
| alu_q3.s | RVM16 | sll, mul (Zcb), slt, xori, HTIF exit |
| alu_rv32.s | RV32IMAF_C | same logic, 32-bit encodings |
| fp_q3.s | RVM16 | 1.0+1.0, fcvt.w.s, HTIF exit |
| fp_rv32.s | RV32IMAF_C | same, with mstatus.FS init |
| fp3_q3.s | RVM16 | fsw/flw/fsqrt/fcvt, HTIF exit |
| fp3_rv32.s | RV32IMAF_C | same, with mstatus.FS init |
| link.ld | - | text at 0x80000000, tohost/fromhost |

## Build and measure (WSL)

    B=/home/milo/rvv-alt/llvm-project/build/bin

    # Q3 ALU (c.mul is Zcb, so +m/+zcb are needed)
    $B/llvm-mc -triple=riscv32 -mattr=+m,+c,+zcb,+zc16q3 -filetype=obj -o alu_q3.o alu_q3.s
    riscv64-linux-gnu-ld -m elf32lriscv -T link.ld -o alu_q3.elf alu_q3.o

    # Q3 FP
    $B/llvm-mc -triple=riscv32 -mattr=+c,+f,+zc16q3 -filetype=obj -o fp_q3.o fp_q3.s
    riscv64-linux-gnu-ld -m elf32lriscv -T link.ld -o fp_q3.elf fp_q3.o

    # RV32 counterparts
    $B/llvm-mc -triple=riscv32 -mattr=+c,+m,+f -filetype=obj -o fp_rv32.o fp_rv32.s
    riscv64-linux-gnu-ld -m elf32lriscv -T link.ld -o fp_rv32.elf fp_rv32.o

    riscv64-linux-gnu-size -A fp_q3.elf | grep .text
    riscv64-linux-gnu-size -A fp_rv32.elf | grep .text

## Run

    # RVM16 (16-bit-only Spike)
    /home/milo/spike-q3/build/spike --isa=RV32IFC_Zc16 --pc=0x80000000 fp_q3.elf

    # RV32IMAF_C (standard Spike)
    /home/milo/riscv-workspace/riscv-isa-sim/build/spike --isa=RV32IMAF_C --pc=0x80000000 fp_rv32.elf

## Results (2026-11-18)

| Kernel | RV32IMAF_C .text | RVM16 .text | Reduction | RV32 | RVM16 |
|---|---:|---:|---:|---|---|
| alu | 42 B | 30 B | 28.6% | RC=0 | RC=0 |
| fp | 42 B | 36 B | 14.3% | RC=0 | RC=0, a1=2 |
| fp3 | 56 B | 50 B | 10.7% | RC=0 | RC=0, a1=2 |

The RV32 FP sizes exclude the one-time mstatus.FS init (6 B); the Q3 PoC
does not do FS init (it writes FPR directly).
