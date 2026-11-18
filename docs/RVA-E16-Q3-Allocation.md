# RVA-E16 Q3 Opcode Allocation (Draft)

**Principle: keep RVC 00/01/10 unchanged; Q3 (bits[1:0]=11) only adds what
RVC + Zcb do not already provide.**

## 1. What RVC + Zcb already cover

- ALU: add, sub, and, or, xor, mv, li, lui, addi, andi, slli, srli, srai.
- Load/store: lw, sw, lb, lh, lbu, lhu, sb, sh (with x8-x15 bases and small
  offsets), plus the sp-relative forms.
- Branch/jump: beqz, bnez, j, jal, jr, jalr, ebreak.
- Zcb: c.mul, c.lbu/c.lh/c.sb/c.sh, c.zext/c.sext/c.not.

So Q3 does **not** need to duplicate add/sub/and/or/xor or the common
immediates.  It only adds:

| Group | Missing operations |
|---|---|
| Integer R | sll, srl, sra (register), slt, sltu |
| M | mul (5-bit), mulh, mulhsu, mulhu, div, divu, rem, remu |
| Immediate | xori, ori, slti, sltiu |
| Load/store | 5-bit-base forms, lhu, and larger offsets |
| FP32 | fadd/fsub/fmul/fdiv/fsqrt/fmin/fmax/fsgnj(n/x), fcvt, fmv, fclass, fcmp, flw/fsw |
| CSR | csrr/csrw/csrs/csrc |
| System | ecall, mret, wfi, fence, fence.i, auipc |
| A | lr/sc (AMO optional) |

## 2. Q3 block map

Q3 has 16,384 patterns.  Use the top 4 bits as a block selector (16 blocks of
1,024 patterns).  A CR3 block spends 5+5 bits on two registers (32 x 32 =
1,024); a block that needs more opcodes spends fewer bits on registers.

| f4 | Block | Layout (10 bits) | Ops | Registers |
|---|---|---|---|---|
| 0 | CR3 sll | rd5 + rs2_5 | 1 | 32 |
| 1 | CR3 srl | rd5 + rs2_5 | 1 | 32 |
| 2 | CR3 sra | rd5 + rs2_5 | 1 | 32 |
| 3 | CR3 slt | rd5 + rs2_5 | 1 | 32 |
| 4 | CR3 sltu | rd5 + rs2_5 | 1 | 32 |
| 5 | CA3 M | funct3 + rd'3 + rs2'3 + 1 | 7 (+1 reserved) | x8-x15 |
| 6 | CI3 | funct2 + rd4 + imm4 | 4 | 16 |
| 7 | LD/ST A | funct2 + reg3 + base2 + off3 | 4 | 8, 4 bases |
| 8 | LD/ST B | funct2 + reg3 + base2 + off3 | 4 | 8, 4 bases |
| 9 | FP A | funct2 + fd4 + fs2_4 | 4 | f0-f15 |
| 10 | FP B | funct2 + fd4 + fs2_4 | 4 | f0-f15 |
| 11 | FP C | funct2 + fd4 + fs2_4 | 4 | f0-f15 |
| 12 | FP D | funct2 + fd4 + fs2_4 | 4 | f0-f15 |
| 13 | FP E | funct2 + fd4 + fs2_4 | 4 | f0-f15 |
| 14 | CSR3 | csr4 + reg4 + op2 | 4 | 16 CSRs, 16 regs |
| 15 | SYS | imm10 | 8-10 | - |

Total: 16 blocks x 1,024 = 16,384 patterns.

## 3. What each block contains

- CR3 (f4 = 0..4): one 32-register two-address op per block:
  sll, srl, sra, slt, sltu.  rd = rd op rs2.
- CA3 M (f4 = 5): mulh, mulhsu, mulhu, div, divu, rem, remu (7 ops;
  funct3=0 reserved because c.mul is the Zcb instruction); 3-bit
  registers x8-x15, 3-bit funct + 1 spare bit.
- CI3 (f4 = 6): xori, ori, slti, sltiu; 4-bit rd (x0-x15), 4-bit immediate
  (0-15).  Larger immediates use the RVC c.li/c.lui or a 3-instruction li
  sequence.
- LD/ST (f4 = 7..8): lb, lh, lw, lbu, lhu, sb, sh, sw; 3-bit register,
  2-bit base (4 bases), 3-bit offset (8 bytes, scaled by size).
- FP (f4 = 9..13): 20 operations in 5 blocks, 4 ops per block, 3-bit FP
  registers f8-f15, 2-address.
- CSR3 (f4 = 14): csrr, csrw, csrs, csrc; 4-bit CSR (16 hot), 4-bit register,
  2-bit op.
- SYS (f4 = 15): ecall, mret, wfi, fence, fence.i, auipc (auipc needs a
  20-bit immediate: use a 2-instruction sequence or a constant pool; the
  block holds the opcode and a 10-bit immediate chunk).

## 4. Tight spots (must be accepted)

| Resource | Budget | Consequence |
|---|---|---|
| CR3 ops | 5 | only shifts and slt/sltu get 32 registers |
| M registers | x8-x15 | M operands outside need mv |
| CI3 immediate | 4 bits | larger constants use c.li/c.lui/li sequences |
| Load/store offset | 3 bits | 8B window; larger offsets need base bump |
| FP registers | f8-f15 | FP values outside need fmv |
| CSR | 16 hot | cold CSRs use li x31 + csr |
| System | 1 block | auipc is a 2-instruction sequence |

These are the price of keeping RVC unchanged and having only 16 bits.

## 5. Why not put more in CR3

One CR3 op costs 1,024 patterns (32 x 32).  Sixteen CR3 ops would fill Q3 and
leave no room for M, FP, CSR or system.  The five CR3 blocks above are the
minimum needed for the integer ops RVC lacks; everything else is in narrower
blocks.

## 6. Next implementation slice

First vertical slice (to prove encoding + execution):

- CR3: sll, slt (2 of the 5)
- CA3: mul (1 of the 8 M ops)
- CI3: xori
- LD/ST: lw, sw
- RVC: c.li, c.add, c.beqz, c.j (unchanged)
- SYS: ecall/ebreak (to exit)

This is enough for a small program: load, shift, compare, multiply, store,
branch, exit.  Once it runs on Spike, add the rest.
