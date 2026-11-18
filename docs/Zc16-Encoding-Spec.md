# Zc16 Encoding Specification (Draft 0.1)

**16-bit forms for the M extension in the RVA-E profile**

## 1. Scope

Zc16 version 1 (`Zc16.M`) defines seven 16-bit, two-address instructions:

```
c.mulh   c.mulhsu   c.mulhu
c.div    c.divu     c.rem     c.remu
```

All operate on 32-bit general-purpose registers.  The encoding reuses the
`C.FLD` code point, which is only present when the D extension is implemented.
RVA-E excludes D, so the code point is free.

## 2. Parcel context

Zc16 instructions are 16-bit parcels with `parcel[1:0] != 11`:

```
15 14 13 | 12 11 10 9 8 | 7 6 5 4 3 | 2 1 0
  0  0  1 |      rd       |    rs2    |  op
```

- `funct3 = 001` (quadrant 0, the former C.FLD slot)
- `rd` and `rs2` are 5-bit GPR numbers (x0-x31)
- `op` is a 3-bit operation selector

The instruction is two-address: `rd` is both a source and the destination.

## 3. Operation selectors

| op | Mnemonic | Semantics (XLEN=32) |
|---|---|---|
| 000 | reserved | `c.mul` lives in Zcb at Q0/funct3=100; do not duplicate |
| 001 | `c.mulh` | `rd = (signed(rd) * signed(rs2)) >> 32` |
| 010 | `c.mulhsu` | `rd = (signed(rd) * unsigned(rs2)) >> 32` |
| 011 | `c.mulhu` | `rd = (unsigned(rd) * unsigned(rs2)) >> 32` |
| 100 | `c.div` | `rd = signed(rd) / signed(rs2)`, RISC-V division semantics |
| 101 | `c.divu` | `rd = unsigned(rd) / unsigned(rs2)` |
| 110 | `c.rem` | `rd = signed(rd) % signed(rs2)` |
| 111 | `c.remu` | `rd = unsigned(rd) % unsigned(rs2)` |

Division by zero and signed overflow follow the base ISA: quotient is all
ones, remainder equals the dividend, and no trap is raised.

## 4. Encoding examples

`c.mulh a0, a1`:

```
funct3 = 001
rd     = a0 = x10 = 0b01010
rs2    = a1 = x11 = 0b01011
op     = 001

bits = 001 01010 01011 001
     = 0x2A59
bytes (little-endian) = 59 2A
```

| Instruction | rd | rs2 | Encoding (hex) | Bytes |
|---|---|---|---|---|
| `c.mulh a0, a1` | x10 | x11 | 0x2A59 | 59 2A |
| `c.mulhsu a0, a1` | x10 | x11 | 0x2A5A | 5A 2A |
| `c.mulhu a0, a1` | x10 | x11 | 0x2A5B | 5B 2A |
| `c.div a0, a1` | x10 | x11 | 0x2A5C | 5C 2A |
| `c.divu a0, a1` | x10 | x11 | 0x2A5D | 5D 2A |
| `c.rem a0, a1` | x10 | x11 | 0x2A5E | 5E 2A |
| `c.remu a0, a1` | x10 | x11 | 0x2A5F | 5F 2A |

## 5. Assembly syntax

```
c.mulh   rd, rs2
c.mulhsu rd, rs2
c.mulhu  rd, rs2
c.div    rd, rs2
c.divu   rd, rs2
c.rem    rd, rs2
c.remu   rd, rs2
```

The first operand is both source and destination.  The assembler must reject
a third operand, and must reject the instruction when `Zc16` is not enabled.

## 6. Interaction with Zcb

Zcb already defines `c.mul` in the Q0/funct3=100 block:

```
c.mul rd', rs2'    ; rd' and rs2' in x8-x15, 2-address
```

Zc16 deliberately does not redefine it.  The `op=000` slot is reserved so a
future revision could provide a 5-bit-register `c.mul` if measurements show
that Zcb's x8-x15 restriction is a problem.

## 7. Future: Zc16.F (FP16 arithmetic)

Zc16.F is not part of version 1.  The sketch below is included so the code
point allocation can be reviewed together.

Code point: Q0/funct3=101 (former C.FSD).

```
15 14 13 | 12 11 10 | 9 8 7 | 6 5 4 | 3 2 1 0
  1  0  1 |   fd     |  fs1  |  fs2  |   op
```

- 3-bit FP register fields, f8-f15 (the same subset used by RVC FP loads)
- 4-bit opcode, 16 operations
- FMA is accumulator form: `fd = fd * fs1 + fs2`, so three register fields
  are enough

Candidate operations: `fadd.h`, `fsub.h`, `fmul.h`, `fdiv.h`, `fma.h`,
`fms.h`, `fnma.h`, `fnms.h`, `fmin.h`, `fmax.h`, `fcmp` variants.

Zc16.F requires Zfh.  With FLEN=32, operands follow the Zfh NaN-boxing rules.

## 8. Future: Zc16.L (FP16 SP-relative load/store)

Code point: Q2/funct3=001 (former C.FLDSP).

```
15 14 13 | 12 | 11 10 9 | 8 7 6 5 4 3 2 | 1 0
  0  0  1 | op |   fs    |     offset     | 1 0
```

- `op=0`: `c.flh.sp fs, off(sp)`
- `op=1`: `c.fsh.sp fs, off(sp)`
- 3-bit FP register field (f8-f15), 7-bit offset scaled by 2 (256-byte window)

## 9. Reserved and conflict rules

1. If D is implemented, the three reused code points are not available and
   Zc16 must not be enabled.  A core that advertises both D and Zc16 is
   non-conformant.
2. `op=000` in Q0/001 is reserved.  An implementation must raise an illegal
   instruction exception on it.
3. Zc16.M does not change the behaviour of any 32-bit instruction.  The
   32-bit forms of `mulh` and friends remain the canonical encoding when the
   compressor cannot satisfy the two-address constraint.
4. No new relocation types are defined in version 1.  Future PC-relative
   forms (if any) must define their own relocations.

## 10. Test vectors

Assembler (LLVM MC, `-mattr=+m,+zc16`):

```
c.mulh   a0, a1   -> [0x59,0x2a]
c.mulhsu a0, a1   -> [0x5a,0x2a]
c.mulhu  a0, a1   -> [0x5b,0x2a]
c.div    a0, a1   -> [0x5c,0x2a]
c.divu   a0, a1   -> [0x5d,0x2a]
c.rem    a0, a1   -> [0x5e,0x2a]
c.remu   a0, a1   -> [0x5f,0x2a]
```

Functional semantics (RV32):

| Case | Input | Expected |
|---|---|---|
| `c.mulh` | rd=0x80000000, rs2=0x80000000 | 0x40000000 |
| `c.mulhu` | rd=0xFFFFFFFF, rs2=0xFFFFFFFF | 0xFFFFFFFE |
| `c.div` | rd=0x80000000, rs2=0xFFFFFFFF | 0x80000000 (overflow) |
| `c.divu` | rd=0xFFFFFFFF, rs2=0x00000002 | 0x7FFFFFFF |
| `c.rem` | rd=0x80000000, rs2=0xFFFFFFFF | 0x00000000 |
| `c.div` | rd=0x00000005, rs2=0x00000000 | 0xFFFFFFFF |
| `c.rem` | rd=0x00000005, rs2=0x00000000 | 0x00000005 |
