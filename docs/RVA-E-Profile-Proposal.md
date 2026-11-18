# RVA-E Profile Proposal

**RISC-V 32-bit Embedded Profile with 16-bit-first Encoding**

| Field | Value |
|---|---|
| Status | Draft 0.1, for discussion |
| Version | 0.1 |
| Date | 2026-11-18 |
| Target | RISC-V Profiles SIG / Unprivileged ISA Committee |
| Working name | RVA-E (E = Embedded) |
| Profile point | RVA-E32 |
| Base ISA | RV32I + MAF + Zicsr + Zifencei |
| 16-bit layer | Zca + Zcb + Zcmp + Zcmt + Zc16 |
| ABI | ILP32F |

## Abstract

RVA-E is a separate profile family for 32-bit embedded processors.  It keeps
the standard RV32IMAF instruction semantics and the standard 32-bit encodings,
and treats every 32-bit instruction as two 16-bit parcels in exactly the way
the C extension already does.  The profile then adds 16-bit forms for the
operations that are still 32-bit today: the M-extension operations not covered
by Zcb's `c.mul`, and (in a later phase) half-precision floating point.

The profile is binary-compatible with RV32IMAF_C for all programs that do not
use the D extension.  It does not modify RVA20/RVA22/RVA23.  Its purpose is to
give the C extension and the Zc* family a well-defined home in the embedded
line, so that the application-processor line can, in a future generation,
deprecate C without orphaning the embedded ecosystem.

## 1. Motivation

### 1.1 C is mandatory in RVA, and that is a deliberate contract

RVA23U64 lists C among its mandatory extensions, next to M, A, F, D and B
([RVA23 profile](https://github.com/riscv/riscv-profiles/blob/main/src/rva23-profile.adoc)).
In November 2023 the RISC-V Profiles TG discussed making C optional in RVA23;
the RVI Board of Directors voted to keep C mandatory, on the grounds that RVA
profiles are binary-compatibility contracts and that an RVA23 core without C
would not run RVA22 binaries ([tech-profiles thread](https://lists.riscv.org/g/tech-profiles/topic/102522954),
[RVI technical newsletter 2023-11-17](https://wiki.riscv.org/download/attachments/60981271/riscv-tech-newsletter-20231117.pdf?api=v2)).

The same profile policy text says that the mandatory set must grow over time,
but also that "RVA profiles may eventually have to deprecate previously
mandatory instructions, but that is unlikely in the near future"
([RVA profile rationale](https://github.com/riscv/riscv-profiles/blob/main/src/rva-profile-overview-body.adoc)).
So the long-term door is open, but the short-term contract is closed.

**This proposal does not try to reopen that contract.**  It takes the C
extension as it is, and gives it a home where its density actually matters:
the 32-bit embedded line.

### 1.2 Embedded needs something that Zc* does not provide

The Zc* family (Zca, Zcf, Zcd, Zcb, Zcmp, Zcmt, Zcmop) already covers most
16-bit code-size needs ([Zc* spec](https://docs.riscv.org/reference/isa/v20240411/unpriv/zc.html)).
It has three gaps for an IMAF-class embedded core:

1. **M**: Zcb provides only `c.mul`.  `mulh`, `mulhsu`, `mulhu`, `div`,
   `divu`, `rem` and `remu` remain 32-bit.
2. **F**: there is no 16-bit FP16 arithmetic.  `c.flw`/`c.fsw` cover F32
   loads and stores, not arithmetic.
3. **Addressing**: there is no 16-bit form for the large-offset global and
   struct accesses that dominate embedded code.

RVA-E fills gap 1 in its first version, gap 2 in a later version, and leaves
gap 3 to an optional vendor macro-op channel (section 5.4).

### 1.3 Why a profile, not an extension

An extension alone cannot carry an ABI, a compliance suite or a software
baseline.  The embedded line needs all three: a fixed set of mandatory
extensions, a binary contract for libraries, and a stable compile target.
That is what a profile provides.  RVA-E is therefore defined as a profile
family with a named profile point (`RVA-E32`), not as another `Z` extension.

## 2. Goals and Non-Goals

### Goals

- Define a 32-bit embedded profile whose default instruction granularity is
  16 bits, with 32-bit instructions as the escape for full IMAF semantics.
- Provide 16-bit forms for the M-extension operations missing from Zcb.
- Preserve binary compatibility with RV32IMAF_C (no D).
- Keep the existing ABI, object format, relocations and 32-bit code path.
- Keep the compiler change confined to the MC/TableGen layer; no change to
  instruction selection, register allocation or scheduling.
- Give the C extension a standards home, without modifying RVA.

### Non-goals

- Changing RVA20/RVA22/RVA23 or the current RVA mandatory set.
- Defining a strict "every instruction is 16 bits, no 32-bit escape" ISA.
  That variant (RV16E) was evaluated and rejected: it loses byte/half-word
  loads in the compressed space, has no CSR access, and increases dynamic
  instruction count by 30-60% (see section 10).
- Standardizing vendor macro-ops in this proposal.
- 64-bit embedded profiles.
- Replacing the C extension.  RVA-E contains C; it does not compete with it.

## 3. Design Rules

### 3.1 Parcel rule

The instruction stream is a sequence of 16-bit parcels:

```
parcel[1:0] != 11  -> a complete 16-bit instruction
parcel[1:0] == 11  -> the low half of a 32-bit instruction;
                      the next parcel is its high half
```

This is exactly the RVC length rule.  Every valid 32-bit RISC-V instruction
has `opcode[1:0] == 11`, so a 32-bit instruction is bit-identical to the two
16-bit parcels of its little-endian representation.  No translation, no
escape prefix, no new relocation.

### 3.2 Binary compatibility

Because the 32-bit path is unchanged:

- every RV32IMAF binary runs unchanged;
- every RV32IMAF_C binary runs unchanged, as long as it does not use D;
- every RVC and Zc* encoding keeps its standard meaning.

The only incompatible case is code that uses `C.FLD`, `C.FSD` or
`C.FLDSP`, i.e. code that requires the D extension.  RVA-E does not support D.

### 3.3 Reused code points

The profile excludes D, so the following 16-bit code points are free:

| Code point | Original instruction | Zc16 use |
|---|---|---|
| Q0, funct3=001 | C.FLD | Zc16.M (this proposal) |
| Q0, funct3=101 | C.FSD | Zc16.F (future) |
| Q2, funct3=001 | C.FLDSP | Zc16.L (future) |

`Q2, funct3=101` is **not** free: Zcmp reuses the `C.FSDSP` encoding, and
Zcmt also draws from the same space ([Zc* spec](https://docs.riscv.org/reference/isa/v20240411/unpriv/zc.html)).
RVA-E mandates Zcmp, so that code point belongs to Zcmp; Zcmt is optional and
must be checked for coexistence in the target implementation.

## 4. Profile Definition

### 4.1 RVA-E32 mandatory set

| Extension | Mandatory | Note |
|---|---|---|
| RV32I | yes | 32 GPR, little-endian |
| M | yes | multiply/divide |
| A | yes | atomics; single-hart MCUs may implement only LR/SC |
| F | yes | single precision, 32 FP registers |
| Zicsr | yes | CSR access |
| Zifencei | yes | instruction-fetch fence |
| Zca | yes | standard RVC base |
| Zcf | yes | compressed F32 loads/stores, for compatibility |
| Zcb | yes | includes `c.mul` |
| Zcmp | yes | push/pop, uses the C.FSDSP code point |
| **Zc16** | **yes** | 16-bit M forms (this proposal) |

### 4.2 Optional

| Extension | Note |
|---|---|
| Zfh | FP16, required if Zc16.F is implemented |
| Zcmt | table jump; also reuses C.FSDSP, so verify coexistence with Zcmp |
| Zc16.F | 16-bit FP16 arithmetic (future) |
| Zc16.L | 16-bit FP16 SP-relative load/store (future) |
| Zbb / Zbs | bit manipulation |
| Zicond | conditional operations |
| Zcmop | compressed may-be-operations |

### 4.3 Excluded

| Extension | Reason |
|---|---|
| D | its 16-bit code points are reused by Zc16 |
| Q | not relevant for embedded |
| V | not relevant for the profile |
| Zcd | requires D |
| Zclsd | requires Zilsd; optional, not in the base profile |

### 4.4 ABI and object format

- ABI: `ILP32F` (F32 arguments in FP registers, 16-byte stack alignment).
- ELF class: ELF32, little-endian, `EF_RISCV_FLOAT_ABI_SINGLE`.
- ISA attribute: `rv32i2p1_m2p0_a2p1_f2p2_zicsr2p0_zifencei2p0_zca1p0_zcf1p0_zcb1p0_zcmp1p0_zc16_1p0` (append `_zcmt1p0` only if Zcmt is enabled).
- No new relocations in version 1: Zc16.M has no PC-relative operand.
- No change to the calling convention, stack layout or unwinding.

## 5. Zc16

### 5.1 Scope of version 1

Zc16 version 1 defines `Zc16.M`: seven two-address 16-bit instructions for
the M operations that Zcb does not provide.  The encoding is specified in
[Zc16-Encoding-Spec.md](Zc16-Encoding-Spec.md).

| Mnemonic | Operation | Code point |
|---|---|---|
| `c.mulh` | `rd = (rd * rs2) >> 32`, signed | Q0/001, op=001 |
| `c.mulhsu` | signed x unsigned high | op=010 |
| `c.mulhu` | unsigned high | op=011 |
| `c.div` | signed divide | op=100 |
| `c.divu` | unsigned divide | op=101 |
| `c.rem` | signed remainder | op=110 |
| `c.remu` | unsigned remainder | op=111 |

`op=000` is reserved: `c.mul` already exists in Zcb at Q0/funct3=100 and
must not be duplicated.

### 5.2 Why these instructions

They are the seven M operations that remain 32-bit in a Zcb system.  In
embedded integer code, `mulh` shows up in fixed-point DSP, `divu`/`remu`
in hashing and address arithmetic, and `div`/`rem` in control code.  Making
them 16-bit is a small but real win (typically 1-3% of static size on integer
workloads), and it is the cheapest possible first step because it needs no
floating-point support.

### 5.3 Why two-address, 5-bit registers

The 13 payload bits of the `C.FLD` code point allow either:

- two 5-bit register fields plus a 3-bit opcode (2-address, all 32 GPRs), or
- three 3-bit register fields plus a 4-bit opcode (3-address, x8-x15 only).

The first form is chosen because it keeps all 32 registers available and needs
no register-allocation hints.  The cost is that the compressor can only fire
when the destination is also a source (`rd == rs1`, or `rd == rs2` for the
commutative `mulh`/`mulhu`).  This is measured in the compiler guide; the
second form can be added later if the hit rate is too low.

### 5.4 Optional vendor macro-op channel

For large-offset loads and stores, a 32-bit custom instruction is a better
tool than a 16-bit one:

```
lw.big   rd, imm15(rs1)     # custom-0
sw.big   rs2, imm15(rs1)    # custom-1
```

The 15-bit offset replaces a `lui + add + lw` sequence (12 bytes) with one
4-byte instruction.  This is optional and vendor-specific; it is not part of
the RVA-E profile and does not consume RVC code points.

## 6. Compatibility

| Binary | Runs on RVA-E32? | Note |
|---|---|---|
| RV32I / RV32IM / RV32IMA / RV32IMAF | yes | 32-bit path bit-identical |
| RV32IMAF_C (no D) | yes | standard RVC preserved |
| RV32IMAFDC | no | `C.FLD/C.FSD/C.FLDSP` reused |
| RV32IMAF_C compiled with Zc16 | only on Zc16 cores | new 16-bit encodings |
| RV64 anything | no | profile is 32-bit |

The compatibility statement is deliberately narrow: **RV32IMAF_C without D**.
That is the set of binaries an embedded vendor is likely to have.

## 7. Toolchain

### 7.1 Compiler

- Target: `riscv32-unknown-elf`, `-march=rv32imaf_zca_zcf_zcb_zcmp_zcmt_zc16`,
  `-mabi=ilp32f`.
- LLVM: one TableGen file plus a feature flag; the 32-bit path is untouched.
  The first patch is in `patches/llvm/`.
- GCC: the same instruction patterns can be added to `riscv.md` with a
  `TARGET_ZC16` predicate; LLVM is the reference implementation.
- The compiler must not emit Zc16 when the target profile does not include it;
  the feature flag is the gate.

### 7.2 Assembler and disassembler

- GNU as and LLVM MC accept the `c.*` mnemonics.
- `llvm-objdump` and `objdump` need the `+zc16` attribute to decode the
  reused code points; without it, those bytes are C.FLD/C.FSD and must be
  reported as such (or rejected if D is absent).
- The ELF attribute string is the source of truth for the disassembler.

### 7.3 Simulator

- Spike: add the seven instruction bodies, the `EXT_ZC16` extension bit and
  the encoding entries.  The patch is in `patches/spike/`.
- QEMU: the same seven instructions can be added to `target/riscv/insn32.decode`
  and `insn_trans`.

## 8. Compliance and Testing

- **RVI compliance suite**: run the existing RV32IMAF tests unchanged.  The
  profile must not change any 32-bit behaviour.
- **Zc16 tests**: assembly/disassembly round-trip, encoding checks, and
  functional tests for the seven operations (including overflow and
  divide-by-zero semantics).
- **Binary compatibility test**: build an RV32IMAF_C program (no D), run it on
  an RVA-E model, and compare the result with a standard RV32IMAF_C model.
- **Code-size benchmark**: Embench-IoT and CoreMark, `.text` measured with
  `llvm-size`; compare `rv32imaf_zca_zcf_zcb_zcmp_zcmt` (baseline) with
  `..._zc16` (new).

## 9. Migration

1. Existing RV32IMAF_C libraries run unchanged; no rebuild required.
2. New libraries are built with Zc16; they require an RVA-E core.
3. Mixed systems can dispatch on the ELF attribute or on a `misa`/device-tree
   property; the profile does not define a new discovery mechanism.
4. Toolchain vendors can ship `-march=..._zc16` as an opt-in flag first,
   and make it the default for `RVA-E32` once the silicon exists.

## 10. Alternatives Considered

### 10.1 Strict 16-bit ISA (RV16E)

Every instruction 16 bits, 16 GPRs, 2-address.  This was evaluated and
rejected: the compressed space has no byte/half-word loads, no CSR access,
limited immediates, and the dynamic instruction count grows by 30-60%.  The
community reached the same conclusion in 2021
([EEVblog thread](https://www.eevblog.com/forum/microcontrollers/risc-v-using-only-the-16-bit-compressed-instructions-is-it-usable/)).
A 16-bit-only core is possible (RV16 shows a 16-bit datapath can run RV32E/I/M/C,
[paper](https://dl.acm.org/doi/10.1007/s11390-022-0910-x)), but it is not a
drop-in replacement for RV32IMAF.

### 10.2 RVC plus Zc* only

The baseline.  It is the right choice if the only goal is a small code-size
improvement with zero toolchain risk.  RVA-E is a superset: it adds the M
forms and keeps the same compatibility story.  Measure the baseline first;
if Zc16 does not beat it by a meaningful margin, do not standardize Zc16.

### 10.3 Redefine the whole 16-bit space

Maximum density, but it breaks binary compatibility with standard RVC and
requires a new ABI.  RVA-E deliberately keeps RVC.

### 10.4 64-bit embedded profile

Out of scope.  The 16-bit density argument is strongest for 32-bit MCUs.

## 11. Open Issues

1. **Name.**  `RVA` currently means 64-bit application processors.  `RVA-E`
   may be read as "RVA with the E extension", which is not the intent.  A
   formal submission should choose a family letter (`RVM` for microcontroller,
   or a new letter) and use `RVA-E` only as a short name.  Candidate formal
   names: `RVM32E`, `RVE32`, `RVA-E32`.
2. **F16 vs F32.**  Version 1 keeps F32 as the mandatory FP and leaves F16 to
   Zfh + Zc16.F.  If the target market is FP16 DSP, F16 could become the
   mandatory FP and F32 the escape.
3. **A mandatory?**  Single-hart MCUs may not need AMO; LR/SC plus interrupt
   masking is enough.  The profile keeps A mandatory for compatibility, with
   an option to relax it in a future revision.
4. **Zcf mandatory?**  Keeping Zcf preserves RV32IMAF_C compatibility; dropping
   it frees two more 16-bit code points.  Version 1 keeps Zcf.
5. **Zc16.F encoding.**  The `C.FSD` code point has 13 payload bits; the
   current sketch uses 3-bit FP registers (f8-f15) and a 4-bit opcode.
   This needs a separate review.
6. **Disassembler behaviour.**  This LLVM tree prints the un-compressed
   mnemonic for compressed instructions.  A submission should decide whether
   `c.mulh` or `mulh` is the canonical disassembly text.

## 12. References

- RVA23 profile: <https://github.com/riscv/riscv-profiles/blob/main/src/rva23-profile.adoc>
- RVA profile rationale: <https://github.com/riscv/riscv-profiles/blob/main/src/rva-profile-overview-body.adoc>
- RVI BoD decision thread: <https://lists.riscv.org/g/tech-profiles/topic/102522954>
- RVI technical newsletter, 2023-11-17: <https://wiki.riscv.org/download/attachments/60981271/riscv-tech-newsletter-20231117.pdf?api=v2>
- Zc* specification: <https://docs.riscv.org/reference/isa/v20240411/unpriv/zc.html>
- C extension specification (chapter 25 of the unprivileged manual).
- Arm A64 (fixed 32-bit, no Thumb): <https://support.arm.com/documentation/dui0741/b/overview-of-the-arm-compiler-6-toolchain/about-armv8-terminology>
- CH32V003 (RV32EC product): <https://www.wch-ic.com/downloads/CH32V003DS0_PDF.html>
- RV16 (16-bit datapath RV32 core): <https://dl.acm.org/doi/10.1007/s11390-022-0910-x>
- EEVblog "only C instructions" discussion: <https://www.eevblog.com/forum/microcontrollers/risc-v-using-only-the-16-bit-compressed-instructions-is-it-usable/>
