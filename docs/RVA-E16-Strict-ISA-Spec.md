# RVA-E16 Strict 16-bit ISA Specification

**Draft 0.1 — working name**

| Field | Value |
|---|---|
| Working name | RVA-E16 |
| Meaning of "16" | 16-bit **instruction width** (not RV32E, not 16 registers) |
| Register file | 32 GPR + 32 FP, 32-bit data path |
| Instruction width | 16 bit, PC += 2, no 32-bit encodings |
| Binary compatibility | none (all code recompiled) |
| Source/ABI compatibility | yes, ILP32-16 |
| Predecessor | RVA-E32 (parcel + 32-bit escape, the compatibility variant) |

## 1. Design Rules

1. Every instruction is exactly 16 bits.  There is no 32-bit escape.
2. Every RV32IMF operation is implemented by **one or more 16-bit instructions**
   ("splicing").  Register-to-register operations use at most 2 instructions;
   FMA uses 3; constants and cold CSRs may use 3 or more.
3. Splicing uses **real instructions only**.  There is no hidden prefix
   register.  The first instruction of a pair writes only the destination or
   the reserved scratch `x31`; therefore an interrupt between the two
   instructions cannot corrupt a live source.
4. The assembler and disassembler may present a 32-bit "macro" view, but the
   object file contains only 16-bit instructions.
5. A verifier rejects any encoded size other than 2 bytes.

## 2. Register File and ABI

- 32 GPRs, `x0` hardwired zero.
- `x31` is **reserved** as the expansion scratch (ALU aliasing, cold CSR
  address, FP compare result).  It is not allocatable by the compiler and is
  not part of the ABI argument registers.
- 32 FP registers, FLEN = 32.
- ABI: **ILP32-16** — 32-bit pointers, 16-byte stack alignment, x31 reserved,
  no 32-bit instructions.
- The ABI is source-compatible with ILP32: existing C code recompiles without
  changes; the register allocation differs only in that x31 is unavailable.

## 3. Encoding Framework

The 16-bit word is partitioned by a **4-bit major opcode**.  Every family has
12 remaining bits, which is the hard budget:

| Family | Layout | Budget |
|---|---|---|
| ALU R (2-address) | `op4 | rd5 | rs2_5 | funct2` | 16 classes x 4 ops |
| ALU I | `op4 | rd5 | imm5 | funct2` | 16 classes x 4 immediate ops |
| Load/store | `op4 | reg5 | base2 | off5` | 16 size/type variants, 4 bases, 32B |
| Branch | `op4 | rs1_5 | off7` | beqz/bnez, ±128B |
| Jump | `op4 | off12` | jal (ra implicit), ±4KB |
| CSR | `op4 | csr5 | reg5 | op2` | 32 hot CSRs, 4 one-register ops |
| FP R (2-address) | `op4 | fd5 | fs2_5 | funct2` | 16 classes x 4 ops |
| System | `op4 | imm12` | ecall/ebreak/mret/wfi/fence |

The exact assignment of `op4` values to families is generated from a table
and checked for conflicts; the budgets above are what must fit.

### 3.1 Load/store base registers

The load/store format uses **4 architectural base registers** (`b0..b3`) and a
5-bit offset scaled by the access size (32B window for word accesses).  The
base registers are ordinary GPRs — recommended mapping: `b0=sp (x2)`,
`b1=gp (x3)`, `b2=fp (x8)`, `b3=dp (x9)`.  `setbase` is not a special
instruction: it is `mv b, rs` or `addi b, rs, 0`, a normal 16-bit ALU op.

A load/store with an arbitrary base register is a 2-instruction splice:

```
mv   b0, rs          ; 1 instruction
lw   rd, off(b0)     ; 1 instruction
```

### 3.2 Branch range

`beqz/bnez` use a 7-bit signed offset (2-byte units, ±128B).  Longer branches
use the standard two-instruction pattern:

```
bnez  rs, +6         ; skip the jump
jal   far_target     ; ±4KB
```

The linker inserts thunks for targets beyond ±4KB.

## 4. Instruction Set

### 4.1 Integer

```
add  sub  and  or  xor  sll  srl  sra  slt  sltu      (2-address)
addi andi ori  xori slti sltiu slli srli srai          (5-bit immediate)
lb lh lw lbu lhu sb sh sw                              (base+offset)
beqz bnez jal jalr
```

`mv rd, rs` is `addi rd, rs, 0`; `nop` is `addi x0, x0, 0`;
`j L` is `jal x0, L`; `ret` is `jalr x0, ra, 0`.

### 4.2 M extension

```
mul mulh mulhsu mulhu div divu rem remu                 (2-address)
```

All eight are single 16-bit instructions in 2-address form.  A 3-address
`mul rd, rs1, rs2` becomes `mv rd, rs1` + `mul rd, rs2`.

### 4.3 F32

The FP subset is **2-address F32**, no FMA:

```
fadd.s fsub.s fmul.s fdiv.s fsqrt.s fmin.s fmax.s
fsgnj.s fsgnjn.s fsgnjx.s
fcvt.s.w fcvt.s.wu fcvt.w.s fcvt.wu.s
fmv.x.w fmv.w.x fclass.s
fcmp.eq.s fcmp.lt.s fcmp.le.s          ; result to x31
flw fsw
```

- All arithmetic is `fd = fd op fs2`; a 3-address source becomes
  `fmv.s fd, fs1` + `fd = fd op fs2` (2 instructions).
- FMA is **not** in the ISA.  `fma.s fd, fs1, fs2, fs3` expands to
  `fmv.s fd, fs1` + `fmul.s fd, fs2` + `fadd.s fd, fs3` (3 instructions,
  non-fused; two roundings).
- Rounding is dynamic from `frm` (the standard RISC-V `frm` field, `111`).
  There is no per-instruction static rounding in 16 bits.
- FP compare writes 0/1 to `x31`; the next instruction is `bnez/beqz x31`
  or `mv rd, x31`.  No FP flags, no `bcc`.

### 4.4 CSR

**Correction to the earlier budget.**  A form with a 4-bit CSR, a 2-bit op,
`rd5` and `rs1_5` consumes 16 bits and leaves no major opcode; adding a
4-bit tag makes it 20 bits.  The feasible hot form is
**one register + a 5-bit CSR address + a 2-bit op**:

```
op4=CSR | csr5 | reg5 | op2          ; 16 bits
```

| op2 | Instruction | Registers |
|---|---|---|
| 00 | `csrr rd, csr` | rd = CSR; rs1 implicit x0 |
| 01 | `csrw csr, rs` | CSR = rs; rd implicit x0 |
| 10 | `csrs csr, rs` | CSR |= rs |
| 11 | `csrc csr, rs` | CSR &= ~rs |

- 32 hot CSRs, all four one-register operations.
- Read-modify-write (`csrrw rd, csr, rs`, `csrrs rd, csr, rs`) is a
  2-instruction splice: `csrr rd, csr` + `csrw csr, rs` (or `csrs`).
- Cold CSRs: `csr5 = 0` is reserved.  `csrr rd, [x31]` / `csrw [x31], rs`
  take the 12-bit CSR address from `x31`.  The sequence is
  `li x31, addr` (2-3 instructions) + `csr op reg` (1).
- Hot CSR list (16 mandatory, 16 implementation-defined):
  `mstatus, misa, mie, mtvec, mepc, mcause, mtval, mscratch, mip, mcycle,
  minstret, mcountinhibit, fcsr, pmpcfg0, pmpaddr0, mhartid`.
  The remaining 16 code points are vendor or profile extensions; more CSRs
  use the cold path.

### 4.5 A extension

- `lr.w rd, (base)` and `sc.w rd, rs2, (base)` fit as 2-address +
  base/offset forms; LR/SC are single 16-bit instructions.
- AMO (`amoadd.w rd, rs2, (rs1)`) needs three registers + aq/rl and does not
  fit.  A single-hart MCU may omit AMO; multi-hart implementations expand it
  to an LR/SC loop (4-6 instructions) or keep it as a 32-bit-only operation
  outside this profile.

### 4.6 System

```
ecall ebreak mret wfi fence fence.i
```

These have no register operands and fit trivially.

## 5. Splicing Templates

| RV32IMF | 16-bit expansion | Count |
|---|---|---|
| `add rd, rs1, rs2` (commutative) | `mv rd, rs1` + `add rd, rs2` | 2 |
| `add rd, rs1, rs2` (`rd==rs2`) | `mv t, rs2` + `mv rd, rs1` + `add rd, t` | 3 |
| `sub rd, rs1, rs2` (`rd==rs2`) | `mv t, rs2` + `mv rd, rs1` + `sub rd, t` | 3 |
| `addi rd, rs1, imm5` | `mv rd, rs1` + `addi rd, imm5` | 1-2 |
| `lw rd, off(base)` | 1 (4 bases, 32B) or `mv b0, base` + `lw` | 1-2 |
| `beq rs1, rs2, L` | `xor t, rs1, rs2` + `beqz t, L` | 2 |
| `blt rs1, rs2, L` | `slt t, rs1, rs2` + `bnez t, L` | 2 |
| `mul rd, rs1, rs2` | `mv rd, rs1` + `mul rd, rs2` | 2 |
| `fadd.s fd, fs1, fs2` | `fmv.s fd, fs1` + `fadd.s fd, fs2` | 2 |
| `fma.s fd, fs1, fs2, fs3` | `fmv.s fd, fs1` + `fmul.s fd, fs2` + `fadd.s fd, fs3` | 3 |
| `feq.s rd, fs1, fs2` | `fcmp.eq.s fs1, fs2` (x31) + `mv rd, x31` | 2 |
| `lui + addi` (32-bit constant) | 3 x `li` or a constant-pool load | 3+ |
| cold CSR | `li x31, addr` + `csr op reg` | 2-4 |

`t` is `x31` (scratch).  The `rd==rs2` case is the only one that needs 3
instructions for an ALU operation; the register allocator should prefer
`rd==rs1` to keep it at 2.

## 6. Compiler Implementation

- Keep the RV32IMF instruction selection, register allocation and ABI.
- Add a **post-RA `RISCVExpand16` pass**: each 32-bit MI is replaced by 1-3
  16-bit MIs using the templates above.  The pass runs after RA and before
  MC emission.
- Reserve `x31` in `RISCVRegisterInfo::getReservedRegs`.
- `RISCVInstrInfoZc16.td` defines the 16-bit instructions with `Size = 2`.
- A verifier rejects any `Size != 2` MI after the pass.
- Constants: v1 uses 3 x `li`; v2 adds a literal-pool pass (ARM
  `ARMConstantIsland` as the model) and a 16-bit PC-relative load.
- FP compare: `fcmp` writes `x31`; no FP flags, no `bcc`.
- CSR: the assembler accepts `csrrw / csrrs` and expands them to
  `csrr` + `csrw`/`csrs`.

## 7. Spike Implementation

- `insn_length()` returns 2 unconditionally for this ISA.
- The 16-bit decode table must cover **all** 16-bit patterns, including
  `bits[1:0] = 11` (RVC reserves those for 32-bit instructions; RVA-E16
  reclaims them).
- No 32-bit decode table; the 32-bit opcodes are not part of the ISA.
- PC advances by 2; `mepc`, branch targets and the trap vector are 2-byte
  aligned.
- New extension name: `Zc16s` or the profile name `rva-e16`; `misa` should
  not advertise C (the encoding is not RVC).

## 8. Code Size Expectations

- Register operations: 1 instruction (2 bytes) when `rd==rs1`, otherwise
  2 instructions (4 bytes).  Worst case is the same as a 32-bit instruction.
- FMA: 3 instructions (6 bytes), 2 bytes more than a 32-bit FMA.
- 32-bit constants: 3 x `li` = 6 bytes, vs 8 bytes for `lui+addi`; a
  constant pool can bring it to 2 bytes per use plus pool data.
- FP code: 2-address expansion keeps bytes equal to 32-bit F, but doubles
  the dynamic instruction count.
- Constant-heavy code is the risk; measure with Embench-IoT and CoreMark
  before claiming a density win.

## 9. Open Issues

1. **Exact opcode map.**  The family budgets are fixed; the bit-level
   assignment (which op4 value is which family) is generated from a table and
   must be checked for conflicts.
2. **Base registers.**  4 bases with a 5-bit offset vs 8 bases with a 4-bit
   offset.  The current choice is 4 bases + 32B.
3. **Branch range.**  ±128B for `beqz/bnez`; thunks for longer branches.
4. **AMO.**  Omit on single-hart, or expand with LR/SC.
5. **FMA.**  Not in the ISA; compiler expands to `fmul`+`fadd`, non-fused.
6. **CSR hot list.**  The 16 mandatory names are a starting point; the
   remaining 16 are profile/vendor defined; more CSRs use the cold path.
7. **Naming.**  `RVA-E16` is a working name; `16` means instruction width,
   not RV32E.  A formal submission may prefer `RV16E` or `RVM16`.

## 10. Relationship to RVA-E32

RVA-E32 (the earlier package) keeps 32-bit M/F and treats Zc16 as a
compression layer; it is binary-compatible with RV32IMAF_C (no D).
RVA-E16 (this document) removes the 32-bit M/F encodings entirely and is not
binary-compatible.  The two share the same Zc16 encoding ideas but are
different profile points; do not mix their object files.
