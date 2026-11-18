# Zc16 Compiler Implementation Guide

**How the first LLVM patch works, and how to extend it**

## 1. Where the change sits

LLVM's RISC-V backend already separates the *instruction* from its *encoding*.
A 32-bit instruction is an `MCInst` with a 4-byte encoding; a compressed
instruction is an `MCInst` with a 2-byte encoding.  The RISC-V backend also
has a table-driven compressor:

- `RISCVInstrInfoC.td` / `RISCVInstrInfoZc.td` define 16-bit instructions and
  `CompressPat` records mapping 32-bit opcodes to 16-bit opcodes.
- `RISCVCompressInstEmitter.cpp` (TableGen backend) turns those records into
  `compressInst` / `uncompressInst`.
- `RISCVCompress` (a MachineFunction pass) calls `compressInst` after register
  allocation.
- The assembler calls `RISCVRVC::compress` in `emitToStreamer` when
  `+exact-asm` is not set.

Therefore, adding a new 16-bit form is **not** a new pass and **not** a change
to instruction selection, register allocation or scheduling.  It is:

1. a feature flag,
2. an instruction definition with the right `Inst` bits,
3. a `CompressPat` mapping,
4. a test.

The 32-bit path is untouched, which is exactly the property RVA-E needs.

## 2. Files changed by the first patch

| File | Change |
|---|---|
| `llvm/lib/Target/RISCV/RISCVFeatures.td` | `FeatureStdExtZc16`, `HasStdExtZc16` |
| `llvm/lib/Target/RISCV/RISCVInstrInfo.td` | include the new `.td` |
| `llvm/lib/Target/RISCV/RISCVInstrInfoZc16.td` | new: 7 instructions + 10 `CompressPat` records |
| `llvm/test/MC/RISCV/zc16-valid.s` | new: MC round-trip test |

The patch is 148 lines including the test.

## 3. The feature flag

```tablegen
def FeatureStdExtZc16
    : RISCVExtension<1, 0,
                     "16-bit integer multiply/divide forms">;
def HasStdExtZc16 : Predicate<"Subtarget->hasStdExtZc16()">,
                    AssemblerPredicate<(all_of FeatureStdExtZc16),
                        "'Zc16' (16-bit integer multiply/divide forms)">;
```

`RISCVExtension` generates the `hasStdExtZc16()` method through
`RISCVGenSubtargetInfo.inc`, so no manual `RISCVSubtarget` edit is needed.
No `RISCVExtensionBitmask` is used, which means `-march=...+zc16` is not yet
accepted; the MC test uses `-mattr=+zc16`.  Adding the bitmask and the
`RISCVISAInfo` entry is a follow-up (section 7).

## 4. The instruction definition

```tablegen
let hasSideEffects = 0, mayLoad = 0, mayStore = 0 in
class RVInst16CM<bits<3> op, dag outs, dag ins, string opcodestr,
                 string argstr>
    : RVInst16<outs, ins, opcodestr, argstr, [], InstFormatOther> {
  bits<5> rd;
  bits<5> rs2;

  let Inst{15-13} = 0b001;
  let Inst{12-8} = rd;
  let Inst{7-3} = rs2;
  let Inst{2-0} = op;
}

def C_MULH : RVInst16CM<0b001, (outs GPR:$rd_wb), (ins GPR:$rd, GPR:$rs2),
                        "c.mulh", "$rd, $rs2">,
             Sched<[WriteIMul, ReadIMul, ReadIMul]> {
  let Constraints = "$rd = $rd_wb";
}
```

Key points:

- `RVInst16` sets `Size = 2` and gives the instruction a 16-bit `Inst` field,
  so TableGen generates the 2-byte encoder without any C++ change.
- `GPR` (not `GPRC`) is used for both registers: the encoding has 5-bit fields,
  so all 32 GPRs are available.  This is the main difference from Zcb's
  `c.mul`, which uses `GPRC` (x8-x15).
- `Constraints = "$rd = $rd_wb"` is the two-address tie.  The assembly string
  exposes only `rd, rs2`; the parser fills `rd_wb` from `rd`.
- `InstFormatOther` is only a classification; the decoder is generated from
  the `Inst` bits.

## 5. The compression patterns

```tablegen
def : CompressPat<(MULH GPR:$rs1, GPR:$rs1, GPR:$rs2),
                  (C_MULH GPR:$rs1, GPR:$rs2)>;
let isCompressOnly = true in
def : CompressPat<(MULH GPR:$rs1, GPR:$rs2, GPR:$rs1),
                  (C_MULH GPR:$rs1, GPR:$rs2)>;
```

The first pattern fires when `rd == rs1`; the second handles the commuted
case `rd == rs2`.  `isCompressOnly` on the second pattern prevents it from
being used as a codegen pattern (it is only a compression alternative).

`mulhsu` is not commutative (signed x unsigned), so it has one pattern only.
`div`/`divu`/`rem`/`remu` are not commutative and also have one pattern
each.

## 6. Build and test

```bash
cd /home/milo/rvv-alt/llvm-project
git checkout rva-e-zc16
make -C build llvm-mc -j20

# assemble
printf 'c.mulh a0, a1\n' | \
  build/bin/llvm-mc -triple=riscv32 -mattr=+m,+zc16 -show-encoding
#   mulh a0, a0, a1   # encoding: [0x59,0x2a]

# reject without the feature
printf 'c.mulh a0, a1\n' | \
  build/bin/llvm-mc -triple=riscv32 -mattr=+m -show-encoding
#   error: instruction requires the following: 'Zc16' ...

# run the MC test
build/bin/llvm-mc -triple=riscv32 -mattr=+m,+zc16 -show-encoding \
  llvm/test/MC/RISCV/zc16-valid.s | \
  build/bin/FileCheck llvm/test/MC/RISCV/zc16-valid.s
```

The local build completed in about one minute after the TableGen regeneration
(20 cores).  The FileCheck test passes.

The `IsRV32` predicate gates the instruction at the codegen/compressor level,
but this tree's assembler still accepts `c.mulh` under
`-triple=riscv64 -mattr=+m,+zc16`; the intended target is
`-march=rv32..._zc16`, and a follow-up should add an RV32 assembler predicate
or reject Zc16 in `RISCVISAInfo` for RV64.

## 7. What is not in the first patch

1. **`-march` parsing.**  `RISCVISAInfo` needs a `Zc16` entry and a
   `RISCVExtensionBitmask`.  Until then, use `-mattr=+zc16`.
2. **Disassembly text.**  This tree's `llvm-mc` prints the un-compressed
   mnemonic (`mulh a0, a0, a1`) for the 2-byte encoding.  A submission should
   decide whether the canonical text is `c.mulh` or `mulh`; the encoding
   itself is correct either way.
3. **F16 forms.**  `Zc16.F` and `Zc16.L` need `Zfh` codegen and FP register
   classes; they are specified in the encoding document but not implemented.
4. **32-bit macro-ops.**  `lw.big`/`sw.big` need a custom opcode and a DAG
   pattern or a peephole; they are optional and vendor-specific.
5. **Relocations.**  Version 1 has no PC-relative Zc16 form, so no new
   relocation types are needed.

## 8. Adding Zc16.F later

The pattern is the same, but the operands are FP registers:

```tablegen
class RVInst16CF<bits<4> op, ...> : RVInst16<...> {
  bits<3> fd;
  bits<3> fs1;
  bits<3> fs2;
  let Inst{15-13} = 0b101;
  let Inst{12-10} = fd;
  let Inst{9-7}   = fs1;
  let Inst{6-4}   = fs2;
  let Inst{3-0}   = op;
}
def C_FADD_H : RVInst16CF<0b0000, (outs FPR16:$fd_wb),
                          (ins FPR16:$fd, FPR16:$fs1, FPR16:$fs2),
                          "c.fadd.h", "$fd, $fs1, $fs2"> {
  let Constraints = "$fd = $fd_wb";
}
```

The FP register class must be restricted to f8-f15 (a 3-bit field).  The
`CompressPat` maps `FADD_H` to `C_FADD_H` under `HasStdExtZfh`.

## 9. Spike implementation plan

The Spike patch follows the same structure:

1. `riscv/encoding.h`: add `MATCH_C_MULH` (0x2001) and `MASK_C_MULH`
   (0xe003), and the other six; add `DECLARE_INSN`.
2. `riscv/decode.h`: add `cm_rd()` and `cm_rs2()` accessors
   (`x(12,5)` and `x(7,3)`).
3. `riscv/insns/c_mulh.h`: `require_extension(EXT_ZC16)`,
   `require_either_extension('M', EXT_ZMMUL)`, then the same arithmetic as
   `mulh.h`, but writing `insn.cm_rd()`.
4. `riscv/riscv.mk.in`: add a `riscv_insn_ext_zc16` list.
5. `riscv/isa_parser.h`: add `EXT_ZC16`; `isa_parser.cc` (or the extension
   table in the target tree) maps `"zc16"` to it.

The local Spike tree is missing `riscv/isa_parser.cc`, so the patch was not
built here.  Apply it to a clean Spike checkout and run:

```bash
./configure --prefix=$PWD/install
make -j20
make install
```

## 10. Review checklist

- [ ] The 32-bit encoding of every existing instruction is unchanged.
- [ ] `c.mulh` is rejected without `+zc16`.
- [ ] `c.mulh` is rejected without `+m`.
- [ ] The encoding is 2 bytes and matches 0x2a59 for `a0, a1`.
- [ ] The compressor fires only when `rd == rs1` (or `rd == rs2` for the
      commutative ops).
- [ ] No new relocation, no ABI change, no change to the 32-bit path.
- [ ] The profile document and the encoding document agree on the code point.
