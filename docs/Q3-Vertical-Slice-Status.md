# Q3 Vertical Slice Status

## What is implemented

| Layer | Item | Status |
|---|---|---|
| Manual | RVA-E16 ISA manual with per-instruction encodings | Draft 0.1 |
| Allocation | 16 Q3 blocks, 16,384 patterns, checked | Done |
| LLVM MC | c.sll/c.slt/c.xori/c.lw/c.sw (Q3) + c.mul (Zcb 0x9EC9) | Works |
| LLVM MC | F32: 20 Q3 FP ops (add/sub/mul/div/sqrt/min/max/fsgnj/eq/lt/le/cvt/fclass/fmv/flw/fsw) | Works |
| Compiler | expand16.py: clang leaf asm -> Q3, f(3,4)=59, Spike RC=0 | Verified (leaf subset) |
| LLVM MC | c.xori (0x6EBF) | Works |
| LLVM MC | c.lw / c.sw (0x7B43 / 0x8FC3) | Works |
| Spike | c.sll/c.slt/c.xori Q3; c.mul Zcb; c.lw/c.sw Q3 | Verified |
| Spike | F32 20 ops (add/sub/mul/div/sqrt/min/max/fsgnj/fsgnjn/fsgnjx/eq/lt/le/cvt/fclass/fmv/flw/fsw) | Implemented; add/fsqrt/fcvt/flw/fsw verified |
| Spike | c.lw_q3 load | Verified |
| Spike | c.sw_q3 store | **Fixed and verified** |
| End-to-end | LLVM-assembled RVC+Q3 (sll/mul/lw/sw), HTIF exit 0, load = 0x120 | Verified |
| End-to-end | LLVM-assembled FP (fmv.w.x/fadd.s/fcvt.w.s), a1 = 2 | Verified |

## End-to-end evidence

Program (assembled with LLVM, linked with riscv64-linux-gnu-ld):

    c.li a0, 3
    c.li a1, 4
    c.sll a0, a1        # 0x052F
    c.li a3, 6
    c.mul a3, a0        # 0x9EC9 (Zcb)
    c.li a2, 5
    c.slt a0, a2        # 0x3533
    ... sp = 0x80000100 ...
    c.swsp a5, 0(sp)     # HTIF exit

Spike command:

    spike --isa=RV32IC_Zc16 --pc=0x80000000 e2e.elf

Result: exit code 0.  The commit trace shows:

    core 0: 0x80000004 (0x052f) x10 0x00000030
    core 0: 0x80000008 (0x9ec9) x13 0x00000120
    core 0: 0x8000000c (0x3533) x10 0x00000000

which are sll (3<<4=48), mul (6*48=288), and slt (48<5=0).

## Open items

1. **c.sw_q3 store: fixed.**  Root cause: the 16-bit whitelist in
   `processor.cc` compared only `desc.match`, and the 32-bit `lb` has
   `match = 0x00000003`, which is numerically equal to the Q3 `c.sll` match
   `0x0003`.  `lb` was therefore registered as a 16-bit instruction and won
   the dispatch for `0x8F83` (store).  The fix compares both match and mask;
   `lb`'s mask `0x707f` differs from `c.sll`'s `0xf003`.  After the fix the
   Q3 store executes and the HTIF program exits 0.
2. **LLVM MC covers all six first-slice instructions.**  c.xori uses a
   4-bit GPR4 register class (0x6EBF); c.lw/c.sw use a BaseGPR register
   class (sp/gp/fp/dp) and encode to 0x7B43/0x8FC3.  Two issues were fixed on
   the way: (a) the CI3 funct2 assignment was inconsistent (manual said
   xori=0, the working encoding is xori=3); (b) stale RISCVGen*.inc files made
   the encoder abort, so a full TableGen regeneration is required after
   editing the Q3 .td.
3. **No Expand16 pass yet.**  The LLVM side is an assembler slice; a C
   program still needs the post-RA expansion pass (32-bit MI -> 1-2 Q3 MI).
4. **Base register mapping is a PoC.**  LLVM's register encoding makes
   sp=2, gp=3, fp=0, dp=1 (truncated GPR numbers), so the manual/Spike base
   map was aligned to 0=fp, 1=dp, 2=sp, 3=gp.  A clean design should use a
   custom getBaseRegOpValue encoder to restore 0=sp, 1=gp, 2=fp, 3=dp.
4. **Spike is a PoC tree.**  insn_length is forced to 2, 32-bit instructions
   are filtered out of the opcode map, and the Boost checks are patched.

## First-slice encodings (final)

| Mnemonic | Encoding |
|---|---|
| c.sll a0, a1 | 0x052F |
| c.slt a0, a2 | 0x3533 |
| c.mul a3, a0 | 0x9EC9 (Zcb) |
| c.xori a0, 15 | 0x6EBF |
| c.lw a4, 0(sp) | 0x7B43 |
| c.sw a5, 0(sp) | 0x8FC3 |

The end-to-end program uses c.sll, c.mul, c.lw, c.sw, assembles with
LLVM, links with riscv64-linux-gnu-ld, runs on Spike, and exits 0.  The load
trace shows x14 = 0x120 from 0x80000200.

## Known issues (priority order)

1. **P0: c.lw/c.sw offset units are inconsistent.**  LLVM writes the raw 3-bit
   field; Spike multiplies it by the access size.  So `c.lw a4, 4(sp)`
   encodes field 4 (byte 16), not byte 4.  Decide whether the assembler takes
   a byte offset (divide by 1/2/4) or the raw field (document it); the manual
   currently implies byte offsets.
2. **Q3 disassembly is implemented (first slice).**  A manual decoder in
   `RISCVDisassembler.cpp` handles bits[1:0]=11 under `+zc16q3` for f4 0-8:
   c.sll/c.srl/c.sra/c.slt/c.sltu, c.xori, c.lw, c.sw.  Round-trip
   assemble/disassemble is verified.  M/FP/CSR/SYS Q3 decode is still
   pending.
3. **P1: base register order is a PoC.**  LLVM register encoding gives
   fp=0, dp=1, sp=2, gp=3; a custom getBaseRegOpValue should restore
   sp=0, gp=1, fp=2, dp=3.
4. **P1: c.lw/c.sw are dual-encoded.**  RVC and Q3 share the mnemonic; the
   assembler picks Q3 when +zc16q3 is on.  A real assembler needs a
   deterministic rule (base register / feature priority).
5. **P2: c.mul is Zcb, not Q3.**  The Q3 CA3 funct3=0 is reserved.  The
   allocation table still says 8 M ops; it is 7 plus the reserved point.
6. **P2: Expand16 is a prototype.**  A standalone translator
   (rva-e/tools/expand16.py) expands a leaf-function subset (sll/mul/add/
   sub/slt/mv/ret, registers x8-x15) from clang's RV32 asm to Q3; f(3,4)=59
   runs on Spike.  The LLVM post-RA pass is not written yet, and branches/
   loads/stores are unsupported.
7. **P2: the Spike and LLVM trees are PoC artifacts.**  Spike forces
   insn_length=2 and filters 32-bit opcodes; the LLVM changes are uncommitted
   in an EVE fork.
8. **F32 is partially implemented.**  Spike executes c.fadd/c.fsub/c.fmul/
   c.fdiv and c.fmv.w.x/c.fmv.x.w; 1.0 + 1.0 = 2.0 (a1 = 0x40000000) is
   verified; fsqrt (4.0 -> 2.0), fcvt.w.s, flw and fsw also pass.  Remaining:
   individual fmin/fmax/fcmp/fclass tests.  LLVM FP MC covers all 20 ops and an
   LLVM-assembled FP program runs on Spike (a1 = 2).  The PoC writes FPR directly
   (WRITE_FREG_NO_DIRTY) because mstatus.FS is 0 at reset; proper FS/CSR
   initialization is still needed.

## Reproduce

    cd /home/milo/q3test
    B=/home/milo/rvv-alt/llvm-project/build/bin
    $B/llvm-mc -triple=riscv32 -mattr=+c,+zc16q3 -filetype=obj -o e2e.o e2e.s
    riscv64-linux-gnu-ld -m elf32lriscv -T link.ld -o e2e.elf e2e.o
    /home/milo/spike-q3/build/spike --isa=RV32IC_Zc16 --pc=0x80000000 e2e.elf
    echo $?   # 0
