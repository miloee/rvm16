# RVA-E16 Code-Size Estimate (rough model)

**Scope:** compare a strict 16-bit RVA-E16 binary with RV32IMAF_C
("rvgc" without D; D is out of scope because RVA-E16 has no D).

These are **rough estimates**, not measurements.  The purpose is to check
whether the "16-bit is always smaller" intuition is reasonable.

## 1. Assumptions

- Baseline RV32IMAF_C: 32-bit instructions are 4 bytes; RVC compresses the
  common cases to 2 bytes.  Static average is about 2.9-3.0 bytes per
  instruction (RVC typically removes 25-30% of the bytes).
- RVA-E16: every instruction is 2 bytes.  A 32-bit operation expands to
  1-3 instructions:
  - 1 instruction when the destination is already the first source
    (`rd == rs1`), which the register allocator can prefer;
  - 2 instructions otherwise (`mv` + 2-address op);
  - 3 instructions for FMA, 32-bit constants, and the `rd == rs2`
    non-commutative case.
- Instruction mix is a typical embedded integer mix and a FP/DSP mix; both
  are guesses and must be replaced by Embench/CoreMark data.

## 2. Bytes per instruction class

| Class | RV32IMAF_C | RVA-E16 | Note |
|---|---|---|---|
| Integer ALU | 3.0 | 2.6 (1.3 instr) | 70% of ops hit `rd==rs1` |
| Load/store | 2.5 | 2.4 (1.2 instr) | 4 bases, 32B window |
| Branch | 2.5 | 3.0 (1.5 instr) | compare + branch |
| M | 3.5 | 3.0 (1.5 instr) | `c.mul` exists in Zcb |
| FP ALU | 4.0 | 3.0 (1.5 instr) | RVC has no FP ALU compression |
| FMA | 4.0 | 6.0 (3 instr) | no FMA in the ISA; `fmul`+`fadd` |
| 32-bit constant | 5.0 | 6.0 (3 `li`) | or constant pool |
| Other | 3.0 | 3.0 | |

## 3. Weighted averages

### Integer mix (ALU 40, LD/ST 25, branch 15, M 5, const 5, other 10)

```
RV32IMAF_C: 0.40*3.0 + 0.25*2.5 + 0.15*2.5 + 0.05*3.5 + 0.05*5.0 + 0.10*3.0
          = 2.93 bytes/instruction

RVA-E16:    0.40*2.6 + 0.25*2.4 + 0.15*3.0 + 0.05*3.0 + 0.05*6.0 + 0.10*3.0
          = 2.84 bytes/instruction
```

**≈ -3%** — essentially neutral.

### FP/DSP mix (ALU 20, LD/ST 25, branch 10, M 5, FP ALU 30, FMA 5, const 5)

```
RV32IMAF_C: 0.20*3.0 + 0.25*2.5 + 0.10*2.5 + 0.05*3.5
          + 0.30*4.0 + 0.05*4.0 + 0.05*5.0
          = 3.30 bytes/instruction

RVA-E16:    0.20*2.6 + 0.25*2.4 + 0.10*3.0 + 0.05*3.0
          + 0.30*3.0 + 0.05*6.0 + 0.05*6.0
          = 3.07 bytes/instruction
```

**≈ -7%** — a modest win, driven by FP ALU (RVC cannot compress it).

## 4. Sensitivity

| Change | Effect |
|---|---|
| ALU `rd==rs1` hit rate drops to 50% | integer average goes to 3.00 → **+2.6%** vs baseline |
| FP `fd==fs1` hit rate drops to 50% | FP average goes to 3.37 → **+2.1%** vs baseline |
| FMA share rises to 10% | FP average +0.1 byte → **+3%** |
| Constant share rises to 10% | both averages rise; RVA-E16 rises slightly more |
| RVC compression rate is higher (35%) | baseline drops to ~2.7; RVA-E16 is **+5%** |

So the sign of the result depends on three numbers: the 2-address hit rate,
the FMA share, and how well RVC compresses the baseline.  None of them is
known without measurement.

## 5. "Does the total capacity not grow?"

Per **register operation**, the worst case is 2 x 16 = 32 bits, equal to one
32-bit instruction.  But the following exceed 32 bits:

| Case | RVA-E16 | 32-bit baseline | Delta |
|---|---|---|---|
| FMA | 6 bytes | 4 bytes | +2 |
| 32-bit constant | 6 bytes | 4-8 bytes | -2 to +2 |
| `sub rd, rs1, rs2` with `rd==rs2` | 6 bytes | 4 bytes | +2 |
| Cold CSR | 4-8 bytes | 4 bytes | 0 to +4 |

So **the total capacity can grow**; the claim "never larger" is only true
for the common 1-2 instruction register operations.  If the workload is
FMA-heavy or constant-heavy, RVA-E16 can be 10-50% larger.

## 6. Conclusion

- Integer code: **neutral** (-3% to +3%).
- FP/DSP code: **-5% to -10%** if the compiler hits the 2-address forms;
  **+2% to +5%** if it does not.
- FMA/constant-heavy code: **larger**.
- The fixed 16-bit front-end (no 32-bit decode, no variable length) is the
  real architectural benefit; code size is not a guaranteed win over RVC.
- Before claiming a density win, measure with Embench-IoT and CoreMark:
  - `llvm-size` on `.text`;
  - dynamic instruction count from Spike;
  - separate integer and FP kernels.

## 7. What would make it clearly smaller

1. **High 2-address hit rate.**  The register allocator must prefer
   `rd == rs1`; without it, the integer win disappears.
2. **No FMA.**  Already decided; FMA would add 2 bytes each.
3. **Constant pool.**  3 x `li` is 6 bytes; a 16-bit PC-relative load plus
   a shared pool can bring repeated constants down to 2 bytes per use.
4. **FP-heavy code.**  RVC does not compress FP ALU, so that is where the
   16-bit encoding wins the most.
