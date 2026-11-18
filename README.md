# RVM16 (RVA-E16)

A strict **16-bit** RISC-V ISA for embedded systems.  RVC quadrants 00/01/10
stay byte-for-byte unchanged; quadrant 11 becomes Q3, a new 16-bit space.
There are no 32-bit instruction encodings.

This is a working proposal and research prototype, not a ratified standard.

## What is here

- a complete draft ISA manual with per-instruction encodings;
- a Q3 block allocation (16 blocks, 16,384 patterns) and a checker;
- LLVM MC support for the first integer slice and all 20 F32 Q3 ops;
- Spike support for the same instructions, including F32;
- a C-to-Q3 Expand16 prototype for a leaf-function subset;
- small code-size benchmarks against RV32IMAF_C.

## Status

| Layer | Status |
|---|---|
| ISA manual | Draft 0.3, encodings for Q3 blocks |
| Q3 allocation | 16 blocks, checked |
| LLVM MC | integer slice + 20 F32 ops |
| Spike | integer slice + 20 F32 ops |
| Q3 disassembly | f4 0-8 (ALU, xori, lw/sw) |
| C path | leaf subset via tools/expand16.py |
| Full Expand16 pass | not implemented |
| CoreMark/Dhrystone | not run yet |

## Quick start

Assemble a Q3 program:

    B=/path/to/llvm-project/build/bin
    $B/llvm-mc -triple=riscv32 -mattr=+c,+f,+zc16q3 -filetype=obj -o demo.o demo.s
    riscv64-linux-gnu-ld -m elf32lriscv -T bench/link.ld -o demo.elf demo.o

Run it on the strict 16-bit Spike:

    spike --isa=RV32IFC_Zc16 --pc=0x80000000 demo.elf

The reset PC must be explicit: Spike's boot ROM is 32-bit code.

## Benchmarks

Hand-written kernels, .text bytes (not a C benchmark suite):

| Kernel | RV32IMAF_C | RVM16 | Reduction |
|---|---:|---:|---:|
| alu | 42 | 30 | 28.6% |
| fp | 42 | 36 | 14.3% |
| fp3 | 56 | 50 | 10.7% |

See [bench/README.md](bench/README.md) for sources and commands.

## Repository layout

    docs/        ISA manual, Q3 allocation, comparison, status, Zhihu draft
    patches/     LLVM patches
    tools/       q3_alloc.py, expand16.py
    bench/       paired RV32 / RVM16 kernels
    expand16/    C -> Q3 prototype artifacts
    tests/       LLVM MC tests

## Documentation

- [ISA manual (AsciiDoc, RISC-V manual style)](docs/RVM16-ISA-Manual.adoc)
- [HTML preview of the manual](docs/RVM16-ISA-Manual.html)
- [Working Markdown notes](docs/RVA-E16-ISA-Manual.md)
- [Q3 allocation](docs/RVA-E16-Q3-Allocation.md)
- [RVM16 vs RV32E](docs/RVM16-vs-RV32E.md)
- [RVM16-C proposal manual (16 GPR, GP/PC, fused branches)](docs/RVM16-C-Manual.adoc)
- [RVM16-C HTML preview](docs/RVM16-C-Manual.html)
- [RVM16-C evaluation: Dhrystone/CoreMark, spill/trampoline/globals](docs/RVM16-C-Evaluation.md)
- [RVM16-C Zhihu article draft](docs/Zhihu-RVM16-C.md)

## RVM16-C status

RVM16-C is the 16-GPR variant: ALU-12, fused bne/blt/blez, GP/PC-relative
load/store, no flags, RVC-compatible quadrants 00/01/10, quadrant 11
redefined as a new ISA.

- Spike-C: FIR 26 B, sum 20 B, x8=70/10;
- LLVM MC: distinct mnemonics under +zc16q3, branch label fixups, same sizes;
- Dhrystone model: 2508 -> 1948 B (-22%; ~2068 with stubs);
- CoreMark core: 6398 -> 6532 B (+2.1%, parity).
- [Vertical slice status](docs/Q3-Vertical-Slice-Status.md)
- [Zhihu draft](docs/Zhihu-Article.md)

## Limitations

- no full Expand16 post-RA pass; only a standalone leaf-function translator;
- Q3 ALU add/sub/and/or/xor/mv come from RVC and only address x8-x15;
- base-register order and load/store offset units are PoC choices;
- the Spike tree is a prototype (insn_length=2, 32-bit opcodes filtered);
- the LLVM changes are not committed upstream.

## License

MIT.  See [LICENSE](LICENSE).
