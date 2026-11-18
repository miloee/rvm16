# RVM16 vs RV32E: a first comparison

Two different ways to make an embedded RISC-V core smaller.  They are often
confused, but they reduce different things.

## 1. What each one is

**RV32E (+C, +Zc*, +M/F)**
- 16 GPRs (x0-x15), 32-bit data path.
- Standard 32-bit instructions plus RVC (2/4-byte).
- Standard ABI (ILP32E), standard GCC/LLVM, existing binaries.
- This is a **register-file reduction**.  It does not change the instruction
  width; the 32-bit fetch/decode path stays.

**RVM16 / RVA-E16**
- 32 GPRs, 32-bit data path.
- Strict 16-bit instructions: RVC 00/01/10 unchanged, Q3 (11) added.
- New ABI and toolchain; no binary compatibility with RV32I/E.
- This is an **instruction-width reduction**.  The register file stays at 32.

## 2. Comparison

| Dimension | RV32E + C | RVM16 |
|---|---|---|
| GPRs | 16 | 32 (x31 scratch) |
| Instruction width | 2 or 4 bytes | 2 bytes only |
| Encoding | standard RVC | RVC 00/01/10 + Q3 11 |
| Binary compatibility | RV32E binaries | none |
| Toolchain | existing GCC/LLVM | new ISA + expansion pass |
| Code size | RVC-level; spills from 16 GPRs | RVC part unchanged; 32-bit ops become 1-2 Q3 ops |
| Dynamic instruction count | lower (3-address 32-bit ops) | higher (2-address + mv) |
| Register pressure | high for IMAF | low |
| Fetch/decode | 32-bit, variable length | 16-bit, fixed length |
| Regfile area | smaller | larger (32 regs) |
| Ecosystem | CH32V003-class, standard | new, needs adoption |
| Standardization | RV32E + Zc* already standard | new profile/extension |

## 3. Code size: rough expectation

- **RV32E + C**: close to RV32I + C, but 16 GPRs cause extra spills in
  register-heavy code.  For integer code the difference is small; for IMAF
  code (especially F32) the spills can cost 5-15%.
- **RVM16**: the RVC part is byte-for-byte identical.  Only the 32-bit
  instructions are replaced by 1-2 Q3 instructions:
  - integer ALU: -3% to +3% (depends on the 2-address hit rate);
  - FP/DSP: -5% to -10% if fd==fs1 hits, +2% to +5% if not;
  - FMA/constant-heavy: larger (FMA 3 instructions, constants 3+).
- So neither is a guaranteed winner; the result depends on the workload.

## 4. When to choose which

Choose **RV32E + C** if:
- you want the standard toolchain and binary ecosystem;
- the product can live with 16 GPRs;
- the fetch/decode is allowed to stay 32-bit/variable-length;
- time-to-market matters.

Choose **RVM16** if:
- the hardware requirement is a 16-bit fetch/decode or a fixed-length
  instruction stream;
- 32 GPRs are needed for IMAF codegen;
- you are willing to own a new ISA, ABI and toolchain;
- code size is the primary metric and the workload is FP-heavy.

They can also be **combined**: RV32E + strict 16-bit (16 GPRs, 2-byte
instructions) is the smallest combination, but register pressure becomes
severe for IMAF.  That variant is not recommended for v1.

## 5. Measurement plan

Do not decide from the table.  Measure:

1. Compile Dhrystone, CoreMark and Linpack for:
   - RV32EC (16 GPRs, C);
   - RV32EC + Zcb + Zcmp (code-size extensions);
   - RV32IMAF_C (32 GPRs, C);
   - RVM16 (model: RVC part unchanged, 32-bit ops expanded to 1-2 Q3 ops).
2. Compare:
   - static .text size;
   - dynamic instruction count (Spike);
   - spill counts (compiler statistics);
   - estimated fetch/decode energy (16-bit vs 32-bit).
3. Decision rule: if RVM16 is not at least 10-15% smaller than RV32EC+Zc* on
   the target workloads, the new ISA is not worth the ecosystem cost.

## 6. Current status

- The allocation table and ISA manual are written.
- A clean Spike build now exists at /home/milo/spike-q3/build/spike.
- The Q3 instruction implementation and LLVM MC patch are next.
