# Submission Cover Letter (draft)

**To:** tech-profiles@lists.riscv.org, tech-unprivileged@lists.riscv.org

**Subject:** [RFC] RVA-E: a 32-bit embedded profile with 16-bit-first encoding

---

Hello,

This is an RFC for a new 32-bit embedded profile family, working name
**RVA-E**.  It is offered as a home for the C extension and the Zc* family in
the embedded line.  It does **not** propose any change to RVA20/RVA22/RVA23.

## Problem

C is mandatory in RVA23 and the BoD reaffirmed that in November 2023.  At the
same time, the embedded line still lacks 16-bit forms for most of the M
extension and for FP16 arithmetic.  Zcb provides only `c.mul`; `mulh`,
`div`, `rem` and FP16 remain 32-bit.

## Proposal

RVA-E32 keeps RV32IMAF semantics and the standard 32-bit encodings.  A 32-bit
instruction is carried as two 16-bit parcels exactly as RVC already does, so
every RV32IMAF_C binary without D is bit-identical and runs unchanged.  The
profile adds `Zc16`, which places 16-bit two-address forms for the seven
missing M operations into the `C.FLD` code point (quadrant 0, funct3=001):

```
c.mulh  c.mulhsu  c.mulhu  c.div  c.divu  c.rem  c.remu
```

No ABI change, no new relocation, no change to the 32-bit path.

## What is available

- Profile proposal and encoding specification.
- An LLVM patch that implements the seven instructions and their
  `CompressPat` mappings; it builds and the MC test passes.
- A Spike patch for the same instructions.

The engine of the design is deliberately small: one TableGen file and one
feature flag.  That is the property we want to preserve for the embedded line.

## Request

1. Is a separate embedded profile family the right vehicle, or should this be
   a `Z` extension under an existing profile?
2. Is the `C.FLD` code point acceptable, given that RVA-E excludes D by
   construction?
3. Is the two-address, 5-bit-register form the right trade-off versus a
   three-address form restricted to x8-x15?
4. Should FP16 (Zc16.F) be the next step, or is the M slice enough for a
   first ratification?

We are happy to provide the Embench/CoreMark measurements and the full
toolchain patches.

Regards,
<author>
