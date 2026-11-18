# RVA-E16 Instruction Set Manual

**Version 0.3 (draft) — working name**

## Contents

1. Scope
2. Programming Model
3. Encoding Framework
4. Base Integer Instructions
5. M Extension
6. A Extension
7. F Extension (F32)
8. CSR Instructions
9. System Instructions
10. Exceptions and Interrupts
11. Encoding
12. Toolchain, Testing, and Examples
13. Open Issues and Tooling Status
14. Revision History

## 1. Scope

RVA-E16 is a 32-bit embedded ISA in which **every instruction is 16 bits**.
It keeps the standard RVC encodings in quadrants 00, 01 and 10 unchanged, and
uses quadrant 11 (formerly the 32-bit escape) as a new 16-bit extension space
called **Q3**.  There are no 32-bit instruction encodings.

- Data path: 32-bit.
- GPRs: 32 (x0-x31); x31 is reserved as the expansion scratch.
- FP: 32 registers, FLEN=32; Q3 FP instructions address f0-f15 (16 regs).
- PC: 32-bit, 2-byte aligned; every instruction advances PC by 2.
- Binary compatibility: none with RV32IMAF_C (32-bit instructions are gone).
- Encoding compatibility: every 16-bit RVC instruction keeps its standard
  encoding.

### 1.1 Profile status and naming

This document is a **proposal**, not a ratified RISC-V International profile.
RVI's ratified profile family is RVA (application) with RVB variants; an RVM
(microcontroller) profile family is in development.  There is **no official
"RVE" profile**: "E" in RISC-V means the RV32E base ISA (16 GPRs), not a
profile letter.

"RVA-E16" is a working name.  Because it mixes RVA (application), E
(embedded / RV32E) and 16 (instruction width), a formal submission should
choose an unambiguous name.  Candidates:

| Name | Reading | Risk |
|---|---|---|
| RVM16 | Microcontroller profile, 16-bit instructions | RVM not yet ratified |
| RVM32E16 | 32-bit MCU, embedded, 16-bit encoding | long |
| RV16E | 16-bit encoding, embedded | may be read as RV32E |
| RVA-E16 | working name only | RVA implies 64-bit application |

## 2. Programming Model

### 2.1 Registers

| Register | Width | Notes |
|---|---|---|
| x0 | 32 | hardwired zero |
| x1-x30 | 32 | general purpose |
| x31 | 32 | reserved expansion scratch; not allocatable |
| f0-f31 | 32 | FP; Q3 FP uses f0-f15 (16 registers) |
| PC | 32 | 2-byte aligned |
| frm/fflags | 32 | FP rounding mode and flags |

The ABI is ILP32-16: 32-bit pointers, 16-byte stack alignment, x31 reserved.

### 2.2 Memory

Little-endian, 32-bit address space.  Loads and stores support byte, halfword
and word.  Misaligned accesses may trap (implementation-defined; the profile
requires natural alignment for words).

### 2.3 Instruction alignment

Every instruction is 2 bytes.  Branch and jump targets must be 2-byte aligned.
A target with bit 0 set raises an instruction-address-misaligned exception.

### 2.4 Locked decisions (2026-11-18)

| Decision | Value |
|---|---|
| GPR file | 32 (x0-x31); x31 reserved as expansion scratch; no RV32E variant |
| F32 | **mandatory**; ABI ILP32F |
| F16 | optional (Zfh), reuses the same formats |
| FMA | not in the ISA; compiler expands to fmv + fmul + fadd (non-fused) |
| FP arithmetic | 2-address, rounding from frm, no per-instruction rm |
| FP compare | fcmp writes x31; no FP flags |

| FP Q3 registers | 16 (f0-f15), 4-bit fields; no f8-f15 restriction |
| FP encoding | funct2 + fd4 + fs2_4; 5 blocks x 4 ops |

B was chosen over 8 registers (too many spills) and 32 registers (would
require reallocating Q3 blocks).  Widening fd/fs2 from 3 to 4 bits costs only
the two spare bits, so the five FP blocks are unchanged.

### 2.5 ABI (ILP32F)

- int/pointer/long are 32 bits, 4-byte aligned; the stack is 16-byte aligned.
- F32 arguments and returns use f0-f7 (caller-saved); f8-f15 are
  callee-saved.
- The first two pointer arguments use s0/x8 and s1/x9; remaining integer and
  pointer arguments use x10-x17.  Returns are in x10/x11; s0/s1 are
  caller-saved argument registers, s2-s11 are callee-saved; x31 is reserved.
- Variadic or unprototyped calls pass all integer/pointer arguments in
  x10-x15, so the callee sees the standard sequence.  Code uses only f0-f15;
  f16-f31 are outside the Q3 ISA.

## 3. Encoding Framework

### 3.1 Quadrants

| bits[1:0] | Meaning |
|---|---|
| 00, 01, 10 | standard RVC instruction (unchanged) |
| 11 | Q3 extension (this manual) |

RVC's 00/01/10 instructions and formats are inherited verbatim; see the
RISC-V C extension specification.  This manual defines only Q3.

### 3.2 Q3 layout

Q3 has 14 payload bits (bits 15:2).  The top 4 bits (f4, bits 15:12) select a
block; each block has 1,024 patterns (bits 11:2).

| f4 | Block | Payload layout (bits 11:2) | Contents |
|---|---|---|---|
| 0 | CR3 sll | rd5, rs2_5 | sll |
| 1 | CR3 srl | rd5, rs2_5 | srl |
| 2 | CR3 sra | rd5, rs2_5 | sra |
| 3 | CR3 slt | rd5, rs2_5 | slt |
| 4 | CR3 sltu | rd5, rs2_5 | sltu |
| 5 | CA3 M | funct3, rd'3, rs2'3, spare1 | mul/mulh/mulhsu/mulhu/div/divu/rem/remu |
| 6 | CI3 | funct2, rd4, imm4 | xori/ori/slti/sltiu |
| 7 | LD/ST A | funct2, reg3, base2, off3 | lb/lh/lw/lbu |
| 8 | LD/ST B | funct2, reg3, base2, off3 | lhu/sb/sh/sw |
| 9 | FP A | funct2, fd3, fs2_3, spare2 | fadd/fsub/fmul/fdiv |
| 10 | FP B | funct2, fd3, fs2_3, spare2 | fsqrt/fmin/fmax/fsgnj |
| 11 | FP C | funct2, fd3, fs2_3, spare2 | fsgnjn/fsgnjx/fcmp.eq/fcmp.lt |
| 12 | FP D | funct2, fd3, fs2_3, spare2 | fcmp.le/fcvt.s.w/fcvt.w.s/fclass |
| 13 | FP E | funct2, fd3, fs2_3, spare2 | fmv.x.w/fmv.w.x/flw/fsw |
| 14 | CSR3 | csr4, reg4, op2 | csrr/csrw/csrs/csrc |
| 15 | SYS | imm10 | ecall/mret/wfi/fence/fence.i/auipc |

The exact operation assignment within a block is given in the instruction
chapters.  The block map is the source of truth for encoding.

## 4. Base Integer Instructions

### 4.1 RVC instructions (inherited, unchanged)

The following keep their standard RVC encodings and semantics:
c.add, c.addi, c.addi4spn, c.addi16sp, c.li, c.lui, c.lw, c.sw, c.lwsp,
c.swsp, c.beqz, c.bnez, c.j, c.jal, c.jr, c.jalr, c.mv, c.and, c.or, c.xor,
c.sub, c.slli, c.srli, c.srai, c.andi, c.nop, c.ebreak, and the Zcb
instructions c.mul, c.lbu, c.lh, c.sb, c.sh, c.zext.b/h/w, c.sext.b/h, c.not.

### 4.2 Q3 integer register operations

| Block | Mnemonic | Semantics |
|---|---|---|
| f4=0 | sll rd, rs2 | rd = rd << (rs2 & 31) |
| f4=1 | srl rd, rs2 | rd = rd >> (rs2 & 31), zero fill |
| f4=2 | sra rd, rs2 | rd = rd >> (rs2 & 31), sign fill |
| f4=3 | slt rd, rs2 | rd = (signed rd < signed rs2) ? 1 : 0 |
| f4=4 | sltu rd, rs2 | rd = (unsigned rd < unsigned rs2) ? 1 : 0 |

All are two-address: rd is both source and destination.  Registers are 5-bit,
so all 32 GPRs are usable.

### 4.3 Q3 immediate operations (block f4=6)

| funct2 | Mnemonic | Semantics |
|---|---|---|
| 00 | xori rd, imm4 | rd = rd XOR imm4 |
| 01 | ori rd, imm4 | rd = rd OR imm4 |
| 10 | slti rd, imm4 | rd = (signed rd < signed imm4) ? 1 : 0 |
| 11 | sltiu rd, imm4 | rd = (unsigned rd < unsigned imm4) ? 1 : 0 |

rd is 4-bit (x0-x15); imm4 is 4-bit, sign-extended for slti/sltiu, zero-extended
for xori/ori.

### 4.4 Q3 load/store (blocks f4=7, f4=8)

Layout: funct2 (operation), reg3 (x8-x15), base2 (b0-b3), off3 (0-7, scaled
by access size).

| Block | funct2 | Mnemonic | Semantics |
|---|---|---|---|
| 7 | 00 | lb reg, off(base) | load byte, sign-extended |
| 7 | 01 | lh reg, off(base) | load halfword, sign-extended |
| 7 | 10 | lw reg, off(base) | load word |
| 7 | 11 | lbu reg, off(base) | load byte, zero-extended |
| 8 | 00 | lhu reg, off(base) | load halfword, zero-extended |
| 8 | 01 | sb reg, off(base) | store byte |
| 8 | 02 | sh reg, off(base) | store halfword |
| 8 | 03 | sw reg, off(base) | store word |

Base registers: b0 = sp (x2), b1 = gp (x3), b2 = fp (x8), b3 = dp (x9).
Offset: off3 x access size (byte 1, half 2, word 4), 0-7 -> 0-28 bytes for
word access.

### 4.5 Pseudoinstructions and splicing

| Pseudo | Expansion | Count |
|---|---|---|
| mv rd, rs | c.addi rd, rs, 0 | 1 |
| li rd, imm6 | c.li rd, imm | 1 |
| li rd, imm32 | 3 x Q3 immediate / constant pool | 3+ |
| nop | c.addi x0, x0, 0 | 1 |
| j L | c.j L | 1 |
| ret | c.jr ra | 1 |
| call L | c.jal L (or auipc+jalr for far) | 1-2 |
| add rd, rs1, rs2 | c.mv rd, rs1; c.add rd, rs2 | 2 |
| sub rd, rs1, rs2 | c.mv rd, rs1; c.sub rd, rs2 | 2 |
| and/or/xor rd, rs1, rs2 | c.mv + c.and/c.or/c.xor | 2 |
| sll/srl/sra rd, rs1, rs2 | c.mv + Q3 sll/srl/sra | 2 |
| slt/sltu rd, rs1, rs2 | c.mv + Q3 slt/sltu | 2 |
| mul rd, rs1, rs2 | c.mv + c.mul (Zcb) | 2 |
| beq rs1, rs2, L | c.xor t, rs1, rs2; c.beqz t, L | 2 |
| blt rs1, rs2, L | Q3 slt t, rs1, rs2; c.bnez t, L | 2 |
| fadd.s fd, fs1, fs2 | fmv.s fd, fs1; fadd.s fd, fs2 | 2 |
| fma.s | fmv + fmul + fadd | 3 |

## 5. M Extension (block f4=5)

Layout: funct3, rd'3, rs2'3, spare1.  Registers are x8-x15; two-address.

| funct3 | Mnemonic | Semantics |
|---|---|---|
| 000 | reserved | c.mul is the Zcb instruction (0x9EC9/0x9C41), not Q3 |
| 001 | mulh rd, rs2 | high 32 bits, signed x signed |
| 010 | mulhsu rd, rs2 | high 32 bits, signed x unsigned |
| 011 | mulhu rd, rs2 | high 32 bits, unsigned x unsigned |
| 100 | div rd, rs2 | signed division |
| 101 | divu rd, rs2 | unsigned division |
| 110 | rem rd, rs2 | signed remainder |
| 111 | remu rd, rs2 | unsigned remainder |

Division by zero: quotient all ones, remainder = dividend, no trap.  Signed
overflow (INT_MIN / -1): quotient INT_MIN, remainder 0.

## 6. A Extension

lr.w and sc.w use a Q3 load/store-like block (reserved for a future revision).
AMO instructions need three registers and do not fit; single-hart
implementations may omit them.  Multi-hart implementations expand AMO to an
lr/sc loop.

## 7. F Extension (F32)

Q3 FP instructions use f0-f15 (16 registers) and are two-address.  The
layout is funct2 (11:10) + fd4 (9:6) + fs2_4 (5:2); all 16 registers are
usable, including f0-f7.  FLEN=32.  Rounding is dynamic from frm; there is no
per-instruction rm field.  There is no FMA.

flw/fsw use block 13 with funct2=2/3, fd4 at 9:6, base2 at 5:4 and
off2 at 3:2 (4-byte window), so f0-f7 can also be loaded and stored.

| Block | funct2 | Mnemonic | Semantics |
|---|---|---|---|
| 9 | 00 | fadd.s fd, fs2 | fd = fd + fs2 |
| 9 | 01 | fsub.s fd, fs2 | fd = fd - fs2 |
| 9 | 10 | fmul.s fd, fs2 | fd = fd * fs2 |
| 9 | 11 | fdiv.s fd, fs2 | fd = fd / fs2 |
| 10 | 00 | fsqrt.s fd, fs2 | fd = sqrt(fs2) |
| 10 | 01 | fmin.s fd, fs2 | minimum |
| 10 | 10 | fmax.s fd, fs2 | maximum |
| 10 | 11 | fsgnj.s fd, fs2 | sign inject |
| 11 | 00 | fsgnjn.s fd, fs2 | sign inject negate |
| 11 | 01 | fsgnjx.s fd, fs2 | sign inject xor |
| 11 | 10 | fcmp.eq.s fs1, fs2 | x31 = (fs1 == fs2) |
| 11 | 11 | fcmp.lt.s fs1, fs2 | x31 = (fs1 < fs2) |
| 12 | 00 | fcmp.le.s fs1, fs2 | x31 = (fs1 <= fs2) |
| 12 | 01 | fcvt.s.w fd, rs1 | int -> float |
| 12 | 10 | fcvt.w.s rd, fs1 | float -> int |
| 12 | 11 | fclass.s rd, fs1 | classify |
| 13 | 00 | fmv.x.w rd, fs1 | FP -> int move |
| 13 | 01 | fmv.w.x fd, rs1 | int -> FP move |
| 13 | 10 | flw fd, off(base) | load word to FP, fd = f0-f15 |
| 13 | 11 | fsw fs, off(base) | store word from FP, fs = f0-f15 |

Block 13: funct2 0/1 are fmv.x.w/fmv.w.x (fd4/fs2_4); funct2 2/3 are
flw/fsw (fd4/base2/off2, 4-byte window).

FMA is not in the ISA.  The compiler expands fma.s to fmv + fmul + fadd
(non-fused; two roundings).

## 8. CSR Instructions (block f4=14)

Layout: csr4 (16 hot CSRs), reg4 (x0-x15), op2.

| op2 | Mnemonic | Semantics |
|---|---|---|
| 00 | csrr rd, csr | rd = CSR |
| 01 | csrw csr, rs | CSR = rs |
| 10 | csrs csr, rs | CSR |= rs |
| 11 | csrc csr, rs | CSR &= ~rs |

The 16 hot CSRs: mstatus, misa, mie, mtvec, mepc, mcause, mtval, mscratch,
mip, mcycle, minstret, mcountinhibit, fcsr, pmpcfg0, pmpaddr0, mhartid.
Cold CSRs: csr4 = 0 is reserved; csrr/csrw with csr4=0 take the 12-bit address
from x31.

## 9. System Instructions (block f4=15)

| imm10 | Mnemonic | Semantics |
|---|---|---|
| 0 | ecall | environment call |
| 1 | ebreak | breakpoint |
| 2 | mret | machine return |
| 3 | wfi | wait for interrupt |
| 4 | fence | memory fence |
| 5 | fence.i | instruction fence |
| 6 | auipc rd, imm | rd = pc + (imm << 12); 2-instruction form |

auipc needs a 20-bit immediate; the block encodes the opcode and a 10-bit
chunk.  A full auipc is a 2-instruction sequence, or the compiler uses a
PC-relative load from a constant pool.

### 9.5 Assembler syntax and disassembly

- Q3 mnemonics use the c. prefix: c.sll, c.srl, c.sra, c.slt, c.sltu,
  c.xori, c.lw, c.sw.
- Load/store syntax: `c.lw rd, off(base)`, with base in {sp, gp, fp, dp}.
  `off` is the 3-bit field, scaled by the access size (0-7).  The current
  PoC base encoding is 0=fp, 1=dp, 2=sp, 3=gp.
- Q3 instructions have bits[1:0] = 11; a disassembler must try the 16-bit
  table when the Zc16q3 feature is enabled.  LLVM's current decoder covers
  f4 0-8 (the five CR3 ops, c.xori, c.lw, c.sw); M/FP/CSR/SYS decode is
  pending.
- RVC c.lw/c.sw and Q3 c.lw/c.sw share a mnemonic.  With +zc16q3 the
  assembler selects Q3; for sp/gp/fp/dp bases the RVC form cannot encode the
  base at all.

## 10. Exceptions and Interrupts

- Instruction-address-misaligned: target bit 0 = 1.
- Illegal instruction: a Q3 pattern not assigned in this manual, or a CSR
  access to an unimplemented CSR.
- Load/store misaligned: implementation-defined; words should be naturally
  aligned.
- ecall/ebreak: trap to mtvec; mepc = PC; mcause set.
- Interrupts: standard RISC-V machine-mode CSRs; the trap vector is 2-byte
  aligned.

## 11. Encoding

### 11.1 General rules

Every Q3 instruction has bits[1:0] = 11.  Bits[15:12] are f4 (the block
selector); bits[11:2] are the payload (10 bits).  The 16-bit word is:

    word = (f4 << 12) | payload | 0b11

The two bytes are stored little-endian: low byte first.

All Q3 mnemonics carry the c. prefix: c.sll, c.slt, c.mul, c.xori,
c.lw, c.sw, c.fadd.s, and so on.  The tables in this chapter sometimes use the
short form (sll, mul, ...) for compactness; the assembler mnemonic always
includes the prefix.

### 11.2 CR3 (f4 = 0..4)

    payload = (rd << 7) | (rs2 << 2)
    word    = (f4 << 12) | (rd << 7) | (rs2 << 2) | 3

| f4 | Mnemonic | Semantics |
|---|---|---|
| 0 | sll rd, rs2 | rd = rd << (rs2 & 31) |
| 1 | srl rd, rs2 | rd = rd >> (rs2 & 31) |
| 2 | sra rd, rs2 | rd = rd >> (rs2 & 31), sign fill |
| 3 | slt rd, rs2 | rd = (signed rd < signed rs2) |
| 4 | sltu rd, rs2 | rd = (unsigned rd < unsigned rs2) |

Example: sll a0, a1 = (0 << 12) | (10 << 7) | (11 << 2) | 3 = 0x052F.

### 11.3 CA3 M (f4 = 5)

    payload = (funct3 << 9) | ((rd-8) << 6) | ((rs2-8) << 3)
    word    = (5 << 12) | payload | 3

rd and rs2 are in x8-x15 (3-bit fields); bit 2 is spare and must be 0.

| funct3 | Mnemonic | Semantics |
|---|---|---|
| 0 | reserved | c.mul is the Zcb instruction |
| 1 | mulh rd, rs2 | high 32, signed x signed |
| 2 | mulhsu rd, rs2 | high 32, signed x unsigned |
| 3 | mulhu rd, rs2 | high 32, unsigned x unsigned |
| 4 | div rd, rs2 | signed divide |
| 5 | divu rd, rs2 | unsigned divide |
| 6 | rem rd, rs2 | signed remainder |
| 7 | remu rd, rs2 | unsigned remainder |

c.mul is the Zcb instruction (0x9EC9 for a3, a0), not a Q3
encoding; the CA3 funct3 000 code point is reserved.

### 11.4 CI3 (f4 = 6)

    payload = (funct2 << 10) | (rd << 6) | (imm << 2)
    word    = (6 << 12) | payload | 3

rd is 4-bit (x0-x15); imm is 4-bit.

| funct2 | Mnemonic | Semantics |
|---|---|---|
| 0 | ori rd, imm | rd = rd OR imm (zero-extended) |
| 1 | slti rd, imm | rd = (signed rd < signed imm) |
| 2 | sltiu rd, imm | rd = (unsigned rd < unsigned imm) |
| 3 | xori rd, imm | rd = rd XOR imm (zero-extended) |

Example: xori a0, 15 = (6 << 12) | (0 << 10) | (10 << 6) | (15 << 2) | 3 = 0x6EBF.

### 11.5 Load/store (f4 = 7 and f4 = 8)

    payload = (funct2 << 10) | ((reg-8) << 7) | (base << 5) | (off << 2)
    word    = (f4 << 12) | payload | 3

reg is x8-x15; base is b0-b3; off is 0-7, scaled by access size.

| f4 | funct2 | Mnemonic |
|---|---|---|
| 7 | 0 | lb reg, off(base) |
| 7 | 1 | lh reg, off(base) |
| 7 | 2 | lw reg, off(base) |
| 7 | 3 | lbu reg, off(base) |
| 8 | 0 | lhu reg, off(base) |
| 8 | 1 | sb reg, off(base) |
| 8 | 2 | sh reg, off(base) |
| 8 | 3 | sw reg, off(base) |

Base map: 0 = fp (x8), 1 = dp (x9), 2 = sp (x2), 3 = gp (x3).
Offset scale: byte x1, halfword x2, word x4.  The LLVM assembler currently
writes the raw 3-bit field; the intended syntax is a byte offset (open issue).

Examples:
- lw a4, 0(sp) = (7 << 12) | (2 << 10) | (6 << 7) | (2 << 5) | (0 << 2) | 3 = 0x7B43.
- sw a3, 0(sp) = (8 << 12) | (3 << 10) | (5 << 7) | (2 << 5) | (0 << 2) | 3 = 0x8FC3.

### 11.6 FP (f4 = 9..13)

FP ALU:

    payload = (funct2 << 10) | (fd << 6) | (fs2 << 2)
    word    = (f4 << 12) | payload | 3

fd and fs2 are 4-bit: all 16 FP registers f0-f15 are usable (no f8-f15
restriction).

| f4 | funct2 | Mnemonic |
|---|---|---|
| 9 | 0 | fadd.s fd, fs2 |
| 9 | 1 | fsub.s fd, fs2 |
| 9 | 2 | fmul.s fd, fs2 |
| 9 | 3 | fdiv.s fd, fs2 |
| 10 | 0 | fsqrt.s fd, fs2 |
| 10 | 1 | fmin.s fd, fs2 |
| 10 | 2 | fmax.s fd, fs2 |
| 10 | 3 | fsgnj.s fd, fs2 |
| 11 | 0 | fsgnjn.s fd, fs2 |
| 11 | 1 | fsgnjx.s fd, fs2 |
| 11 | 2 | fcmp.eq.s fs1, fs2 |
| 11 | 3 | fcmp.lt.s fs1, fs2 |
| 12 | 0 | fcmp.le.s fs1, fs2 |
| 12 | 1 | fcvt.s.w fd, rs1 |
| 12 | 2 | fcvt.w.s rd, fs1 |
| 12 | 3 | fclass.s rd, fs1 |

For fcmp: the fd field carries fs1; the result is written to x31.
For fcvt/fclass: the fd field carries the FP register, the fs2 field carries
the integer register (4-bit, x0-x15).

FP move/load/store (f4 = 13):

| funct2 | Mnemonic | Fields |
|---|---|---|
| 0 | fmv.x.w rd, fs1 | fd4 = rd, fs2_4 = fs1 |
| 1 | fmv.w.x fd, rs1 | fd4 = fd, fs2_4 = rs1 |
| 2 | flw fd, off(base) | funct1=0, fd4, base2, off3 (8B) |
| 3 | fsw fs, off(base) | funct1=1, fd4, base2, off3 |

For flw/fsw: word = (13 << 12) | (funct2 << 10) | (fd << 6) |
(base << 4) | (off << 2) | 3, with funct2 = 2 for flw and 3 for fsw.  fd is
4-bit, so f0-f7 can be loaded and stored.

### 11.7 CSR3 (f4 = 14)

    payload = (csr4 << 8) | (reg4 << 4) | (op2 << 2)
    word    = (14 << 12) | payload | 3

csr4 = 0 is the cold path: the 12-bit CSR address is in x31.  csr4 = 1..15
select the 15 hot CSRs:

| csr4 | CSR | csr4 | CSR |
|---|---|---|---|
| 1 | mstatus | 9 | mcycle |
| 2 | misa | 10 | minstret |
| 3 | mie | 11 | mcountinhibit |
| 4 | mtvec | 12 | fcsr |
| 5 | mepc | 13 | pmpcfg0 |
| 6 | mcause | 14 | pmpaddr0 |
| 7 | mtval | 15 | mhartid |
| 8 | mscratch | | |

op2: 0 = csrr, 1 = csrw, 2 = csrs, 3 = csrc.  reg4 is x0-x15.

### 11.8 SYS (f4 = 15)

    payload = (imm10 << 2)
    word    = (15 << 12) | (imm10 << 2) | 3

| imm10 | Instruction |
|---|---|
| 0 | ecall |
| 1 | ebreak |
| 2 | mret |
| 3 | wfi |
| 4 | fence |
| 5 | fence.i |
| 6 | auipc low half |
| 7 | auipc high half |

auipc is a two-instruction sequence: low half adds imm[9:0] << 12, high half
adds imm[19:10] << 22, or the compiler uses a constant pool.

### 11.9 RVC base

The 00/01/10 quadrants are exactly RVC v2.0.  No RVC encoding is changed.
The instructions used by the compiler in this manual (c.li, c.lui, c.addi,
c.andi, c.slli, c.srli, c.srai, c.add, c.sub, c.and, c.or, c.xor, c.mv,
c.lw, c.sw, c.lwsp, c.swsp, c.beqz, c.bnez, c.j, c.jal, c.jr, c.jalr, c.nop,
c.ebreak) keep their standard RVC encodings.

### 11.10 Complete Q3 block map

| f4 | Block | Operation |
|---|---|---|
| 0 | CR3 | sll |
| 1 | CR3 | srl |
| 2 | CR3 | sra |
| 3 | CR3 | slt |
| 4 | CR3 | sltu |
| 5 | CA3 | mulh/mulhsu/mulhu/div/divu/rem/remu (funct3 0 reserved; c.mul is Zcb) |
| 6 | CI3 | xori/ori/slti/sltiu |
| 7 | LD/ST | lb/lh/lw/lbu |
| 8 | LD/ST | lhu/sb/sh/sw |
| 9 | FP | fadd/fsub/fmul/fdiv |
| 10 | FP | fsqrt/fmin/fmax/fsgnj |
| 11 | FP | fsgnjn/fsgnjx/fcmp.eq/fcmp.lt |
| 12 | FP | fcmp.le/fcvt.s.w/fcvt.w.s/fclass |
| 13 | FP | fmv/flw/fsw |
| 14 | CSR | csrr/csrw/csrs/csrc |
| 15 | SYS | ecall/ebreak/mret/wfi/fence/fence.i/auipc |

### 11.11 Worked example

The first Spike test program:

| Address | Word | Instruction |
|---|---|---|
| 0x80000000 | 0x450D | c.li a0, 3 |
| 0x80000002 | 0x4591 | c.li a1, 4 |
| 0x80000004 | 0x052F | c.sll a0, a1 |
| 0x80000006 | 0x4699 | c.li a3, 6 |
| 0x80000008 | 0x9EC9 | c.mul a3, a0 (Zcb) |
| 0x8000000A | 0x4615 | c.li a2, 5 |
| 0x8000000C | 0x3533 | c.slt a0, a2 |
| 0x8000000E | 0x6EBF | c.xori a0, 15 |
| 0x8000001C | 0x8FC3 | c.sw a3, 0(sp) |
| 0x8000001E | 0x7B43 | c.lw a4, 0(sp) |
| 0x8000002E | 0x8FC3 | c.sw a5, 0(sp) |

### 11.12 Encoding space

RVC uses 3 quadrants (00/01/10) = 49,152 patterns; Q3 uses quadrant 11 =
16,384 patterns; total 65,536.  Q3 is divided into 16 blocks of 1,024
patterns (f4 x 10-bit payload).

## 12. Toolchain, Testing, and Examples

### 12.1 LLVM MC

The Q3 instructions are assembled with:

    llvm-mc -triple=riscv32 -mattr=+c,+f,+zc16q3

c.mul is the Zcb instruction, so add +m (or +zmmul) and +zcb when a kernel
uses it.  The CA3 M block (c.mulh/mulhsu/mulhu/div/divu/rem/remu) and the
CSR block (c.csrr/csrw/csrs/csrc) are also implemented.  The LLVM CSR syntax
currently takes the numeric csr4 (for example c.csrr a0, 8 for mscratch);
CSR names are not parsed yet.  The disassembler handles f4 0-8 (CR3
shifts/compare, c.xori, c.lw/c.sw); M/FP/CSR/SYS decode is still pending.

### 12.2 Spike

    spike --isa=RV32IFC_Zc16 --pc=0x80000000 elf

The PoC Spike is strict 16-bit: insn_length is forced to 2 and 32-bit
instructions are filtered out of the opcode map.  It executes the integer
slice, the CA3 M block, the CSR block, and the 20 F32 Q3 operations.  The
reset PC must be set explicitly because Spike's boot ROM contains 32-bit
code.

### 12.3 C to Q3 prototype

A standalone translator (tools/expand16.py) turns clang -O2 small-integer-
function assembly into Q3.  For

    int f(int a, int b) { return (a << b) + (a * b) - (a < b); }

the result f(3,4) = 59 runs on Spike (RC=0).  A sum loop over 1,2,3,4 also
returns 10.  This is not the LLVM post-RA pass; calls, stack frames, and large
offsets are not supported yet (simple branches and word loads/stores are).
All values must be in x8-x15 because Q3/RVC add/sub/mv cannot encode x16-x31.

### 12.4 Comparison with RV32E / RV32EC + Zc*

RV32E reduces the register file to 16 GPRs; RVM16 reduces the instruction
width to 16 bits and keeps 32 GPRs.  They are orthogonal.  RV32E is standard
and has a toolchain; RVM16 needs a new ISA, ABI, and compiler path.  Small
hand-written kernels currently show 28.6% (ALU), 14.3% (FP), and 10.7%
(FP load/store) .text reduction against RV32IMAF_C.  A CoreMark/Dhrystone
comparison is still needed; see RVM16-vs-RV32E.md.

## 13. Open Issues and Tooling Status

1. **Offset units.**  The assembler takes the raw 3-bit field; the manual
   describes a byte offset scaled by access size.  Pick one and make the
   encoder/decoder agree.
2. **Base register map.**  The PoC uses 0=fp, 1=dp, 2=sp, 3=gp because LLVM
   register encoding is the GPR number.  A custom getBaseRegOpValue should
   restore 0=sp, 1=gp, 2=fp, 3=dp.
3. **c.lw/c.sw dual encoding.**  RVC and Q3 share the mnemonic; a deterministic
   selection rule is needed.
4. **Q3 decode coverage.**  M/FP/CSR/SYS patterns are not decoded yet.
5. **F32 implementation.**  The ISA is specified but Spike and LLVM do not
   execute/emit FP instructions yet.
6. **Expand16.**  No post-RA pass; C code cannot be compiled to Q3.
7. **Tooling state.**  The Spike tree is a PoC (insn_length=2, 32-bit opcodes
   filtered); the LLVM changes are uncommitted in an EVE fork.

## 14. Revision History

- 0.1: initial manual; RVC base inherited; Q3 block map; first slice.
- 0.2: 32 GPR and F32 locked; FP Q3 uses 16 registers f0-f15; CA3 M is
  7 ops + reserved (c.mul is Zcb); Q3 disassembly for f4 0-8; ABI and open
  issues added.
- 0.3: contents; toolchain/testing/C-prototype/comparison chapter; f0-f15
  consistency fixes; version bump.
