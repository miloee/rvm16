# RVA-E16 Encoding: RVC + Q3

**Constraint: keep the existing C-extension encodings unchanged; only add new
instructions in the quadrant that used to be the 32-bit escape.**

## 1. Principle

RVC partitions the 16-bit space by bits[1:0]:

    00 / 01 / 10  -> standard RVC instructions (unchanged)
    11            -> in RVC: the low half of a 32-bit instruction
                  -> in RVA-E16: the new 16-bit extension quadrant (Q3)

RVA-E16 has no 32-bit instructions, so Q3 is free.  The 00/01/10 quadrants keep
their standard RVC meanings, formats and field layouts.  Q3 reuses the same
format shapes with **14 payload bits** (16 minus the 2-bit quadrant), one more
bit than the 13-bit payload of Q0/Q2.

This preserves the C-extension encoding rules and gives 16,384 new patterns.

**Compatibility caveat:** a standard RV32IMAF_C binary still contains 32-bit
instructions, so it does not run.  What is preserved is the encoding of every
16-bit RVC instruction; an RVC-only binary runs unchanged.

## 1.1 Q3 budget: CR3 is not free

Q3 has 2^14 = 16,384 patterns.  One CR3 opcode consumes 32 x 32 = 1,024
patterns (rd5 x rs2_5).  Therefore:

- 16 CR3 ops = 16 x 1,024 = **16,384 = the whole quadrant**;
- 8 CR3 ops = 8,192, leaving 8,192 patterns for eight 1,024-pattern
  sub-formats;
- 12 CR3 ops leave only 4 sub-format blocks.

So "put everything in CR3" is possible only if CR3 is the **only** Q3 format.
The moment CA3/CI3/CSR3 are needed, CR3 must give up opcode values.  The table
below is therefore a set of **candidates**, not a simultaneous allocation.

## 2. Q3 format candidates (all with bits[1:0] = 11)

| Format | Layout | Use |
|---|---|---|
| CR3 | funct4[15:12] + rd5[11:7] + rs2_5[6:2] | 2-address ALU/M/FP |
| CI3 | funct3[15:13] + imm5[12:8] + rd5[11:7] + imm[4:0][6:2] | immediate ops |
| CA3 | funct6[15:10] + funct2[9:8] + rd'3[7:5] + rs2'3[4:2] | 2-address, x8-x15, 256 ops |
| CB3 | funct3[15:13] + off8[12:5] + rs1'3[4:2] | branches, x8-x15 |
| CJ3 | funct3[15:13] + off11[12:2] | jumps |
| CL3 | funct3 + imm[5:3] + rs1'3 + imm[7:6] + rd'3 | loads, x8-x15 |
| CSR3 | csr5[15:11] + reg5[10:6] + op4[5:2] | CSR, 32 hot |

The field positions mirror the RVC CI/CA/CB/CJ/CL formats, so the existing
encoding rules and assembler conventions carry over.

## 3. CR3: 16 two-address operations

Semantics: rd = rd <op> rs2; 5-bit registers, all 32 GPRs.

| funct4 | Op | funct4 | Op |
|---|---|---|---|
| 0000 | add | 1000 | slt |
| 0001 | sub | 1001 | sltu |
| 0010 | and | 1010 | mul |
| 0011 | or | 1011 | mulh |
| 0100 | xor | 1100 | div |
| 0101 | sll | 1101 | divu |
| 0110 | srl | 1110 | rem |
| 0111 | sra | 1111 | remu |

This single format covers the integer ALU ops that RVC lacks and the whole M
extension.  Zcb already has a c.mul for x8-x15; CR3's mul is the 5-bit-register
version needed once 32-bit M is removed.

## 4. CI3: immediates

Semantics: rd = rd <op> imm6; 5-bit rd, 6-bit immediate.

| funct3 | Op | funct3 | Op |
|---|---|---|---|
| 000 | addi | 100 | slti |
| 001 | andi | 101 | sltiu |
| 010 | ori | 110 | slli |
| 011 | xori | 111 | srli / srai (imm[5] selects) |

32-bit constants are built from 3 x CI3 (11+11+10) or a constant pool.

## 5. CSR3

csr5 + reg5 + op4: 32 hot CSRs, 16 operation codes.  The 5-bit register field is
rd for reads and rs1 for writes/sets/clears.

| op4 | Instruction |
|---|---|
| 0000 | csrr rd, csr |
| 0001 | csrw csr, rs |
| 0010 | csrs csr, rs |
| 0011 | csrc csr, rs |
| 0100-1111 | RMW forms / vendor |

csrrw/csrrs with both rd and rs1 are 2-instruction splices (csrr + csrw/csrs).
Cold CSRs use "li x31, addr" + a Q3 CSR op with csr5 = 0.

## 6. FP32 in Q3

- CR3 with 5-bit fd + 5-bit fs2 + 4-bit funct: fadd.s, fsub.s, fmul.s, fdiv.s,
  fsqrt.s, fmin.s, fmax.s, fsgnj.s, fsgnjn.s, fsgnjx.s (2-address, 32 FP regs).
- CA3 with 3-bit FP registers (f8-f15) for 2-address FP when more than 16
  funct values are needed; it is not a 3-address format.
- CL3 with 3-bit fd and 3-bit base for flw/fsw; or a dedicated CL3.fp with
  5-bit fd + 5-bit base + 4-bit offset (16B window).
- fcmp: CR3 with fd = x31 fixed; the predicate is in funct4.  Result 0/1 in
  x31; bnez/beqz x31 consumes it.  No FP flags, no bcc.
- fcvt/fmv/fclass: CR3 with one integer register and one FP register; the
  5-bit fields can hold either file.

## 7. What RVC already covers

00/01/10 already provide c.add, c.addi, c.addi4spn, c.addi16sp, c.li, c.lui,
c.lw, c.sw, c.lwsp, c.swsp, c.beqz, c.bnez, c.j, c.jal, c.jr, c.jalr, c.mv,
c.and, c.or, c.xor, c.sub, c.slli, c.srli, c.srai, c.andi, c.nop, c.ebreak,
and Zcb's c.mul, c.lbu/c.lh/c.sb/c.sh.

Q3 adds what RVC lacks: slt/sltu, register shifts, the full M extension, F32,
CSR, auipc, fence, system instructions, LR/SC.

## 8. Code-size impact

- The RVC part is byte-for-byte unchanged; only the 32-bit instructions are
  replaced by 1-2 Q3 instructions.
- A 3-address ALU op that RVC cannot compress becomes 1 Q3 "c.add rd, rs2" if
  rd==rs1, otherwise 2 Q3 instructions (4 bytes) - same as 32-bit.
- FP ALU becomes 1-2 Q3 instructions (2-4 bytes vs 4 bytes); FMA 3 (6 bytes).
- The benchmark estimate therefore isolates the delta to the non-RVC ops.

## 9. Open items

1. Whether CR3's 16 ops include the M extension or M gets its own Q3 sub-space
   (CR3 is exactly 16, so it fits).
2. Whether FP loads/stores use CL3 (3-bit regs) or a dedicated 5-bit form.
3. The 32 hot CSR list.
4. Whether Zcb's c.mul is kept alongside CR3's 5-bit mul.
5. Q3 sub-format allocation for system/fence/AMO.
