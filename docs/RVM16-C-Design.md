# RVM16-C 完整方案（草案 0.1）

状态：方向已确认，编码/ABI/验证计划完整草案；尚未实现。RVM16-A（32 GPR）保留为 negative control。

## 1. 摘要

RVM16-C 是一个**兼容 RVC、no-flags、16 GPR、严格 16 位**的 RISC-V 变体。目标不是“所有情况都小”，而是在嵌入式 C 的基准集上，code size 比 RVGC 小 5-10%，最坏情况不超过 +5%。

和 RVM16-A 的区别：

- A：32 GPR、2-address、无融合分支；通用 C 反而比 RVGC 大。
- C：16 GPR、2-address 为主 + GP/PC-relative load/store、融合 bne/blt/blez；用低 8 位字段换分支和指针基址。

## 2. 约束

- quadrant 00/01/10 的 RVC 编码逐字节不变；只有 quadrant 11 是 Q3。
- no-flags：条件分支必须自带比较。
- 16 个架构 GPR（x0-x15）。
- 严格 16 位：没有 32 位指令，没有 Thumb-2 式逃生口。
- ABI、工具链、库都要重编；不与 A 混编。

## 3. RVC baseline

“RVC 不变”指具体基线：

- C v2.0：quadrant 00/01/10 的编码逐字节不变。
- Zcb 必选：c.mul、c.lbu、c.lh、c.lhu、c.sb、c.sh、c.zext.b/h/w、c.sext.b/h、c.not，使用标准 Zcb 编码；RVM16-C 的字节/半字访问依赖它。
- Zcmp/Zcmt 可选：push/pop、table jump 使用标准编码，RVM16-C 不重新定义。
- Q3 助记符虽然带 c. 前缀，但编码都在 quadrant 11；没有改任何 RVC 编码。
- RVC 中寻址 x16-x31 的形式（例如 c.lwsp rd=x20）在 16 GPR 下非法。

## 4. 寄存器模型与 ABI

| 寄存器 | 角色 |
|---|---|
| x0 | zero |
| x1 | ra |
| x2 | sp |
| x3 | gp（GP-relative 必需） |
| x4 | tp（可选） |
| x5-x6 | 临时/保留 |
| x7 | 冷 CSR 地址 scratch，不分配 |
| x8-x13 | a0-a5：参数/返回/临时 |
| x14-x15 | s0-s1：callee-saved |
| x16-x31 | 不存在 |

ABI（RVM16-C ILP32F-16）：

- 整数/指针参数 a0-a5 = x8-x13；返回 a0/a1 = x8/x9；
- 前两个指针参数自然落在 x8/x9，正好是 Q3 的 base 寄存器；
- F32 参数 f0-f7，返回 f0；f8-f15 callee-saved；
- s0/s1 只有在函数用到时才保存；
- sp/ra 用 RVC 和 Q3 的 4-bit load/store 保存；
- gp = x3 指向 small-data 段起始，启动时设一次；GP/PC-relative off 范围 0..124 B；
- 栈 16 B 对齐；
- 变参：a0-a5 + f0-f7；没有 x16+；
- 分支操作数必须在 x8-x15，编译器负责把分支用值放低 8 个。

## 5. 编码框架

16 位字：bits[1:0] = 0b11；bits[15:12] = f4；bits[11:2] = 10-bit payload。

    word = (f4 << 12) | payload | 0b11

Q3 的 16 个 f4 block：

| f4 | 用途 | 编码 |
|---|---|---|
| 0 | ALU-12 A | funct2 + rd4 + rs2_4：add/sub/and/or |
| 1 | ALU-12 B | funct2 + rd4 + rs2_4：xor/sll/srl/sra |
| 2 | ALU-12 C | funct2 + rd4 + rs2_4：slt/sltu + 2 reserved |
| 3 | GP/PC-relative | funct2 + reg3 + off5：lwgp/swgp/lwpc |
| 4 | M | funct3 + rd3 + rs2_3：mulh/mulhsu/mulhu/div/divu/rem/remu |
| 5 | c.bne | rs1_3 + rs2_3 + off4 |
| 6 | c.blt | rs1_3 + rs2_3 + off4；bge 交换 rs1/rs2 |
| 7 | c.blez | rs_3 + off7 |
| 8 | LD/ST | funct2 + reg4 + base2 + off2：lw/sw + 2 reserved |
| 9-13 | F32 | funct2 + fd4 + fs2_4，20 条 |
| 14 | CSR | csr4 + reg4 + op2 |
| 15 | SYS | imm10 |

字段宽度：

- 4-bit 寄存器：x0-x15；
- 3-bit 寄存器：x8-x15；
- 分支偏移按 2 字节缩放。

## 6. ALU-12（f4=0..2）

编码：

    word = (f4 << 12) | (funct2 << 10) | (rd << 6) | (rs2 << 2) | 0b11

rd、rs2 是 x0-x15；2-address：rd = rd op rs2。

| f4 | funct2 | 指令 | 语义 |
|---|---|---|---|
| 0 | 0 | add rd, rs2 | rd = rd + rs2 |
| 0 | 1 | sub rd, rs2 | rd = rd - rs2 |
| 0 | 2 | and rd, rs2 | rd = rd & rs2 |
| 0 | 3 | or rd, rs2 | rd = rd | rs2 |
| 1 | 0 | xor rd, rs2 | rd = rd ^ rs2 |
| 1 | 1 | sll rd, rs2 | rd = rd << (rs2 & 31) |
| 1 | 2 | srl rd, rs2 | rd = rd >> (rs2 & 31)，零填充 |
| 1 | 3 | sra rd, rs2 | rd = rd >> (rs2 & 31)，符号填充 |
| 2 | 0 | slt rd, rs2 | rd = (signed rd < signed rs2) |
| 2 | 1 | sltu rd, rs2 | rd = (unsigned rd < unsigned rs2) |
| 2 | 2-3 | reserved | |

## 7. GP/PC-relative load/store（f4=3）

编码：

    word = (3 << 12) | (funct2 << 10) | (rd3 << 7) | (off5 << 2) | 0b11

- rd3 是 x8-x15；
- funct2：0 = lwgp，1 = swgp，2 = lwpc，3 = reserved；
- off5 是无符号 0-31，按 4 B 缩放，范围 0..124 B；
- lwgp/swgp：地址 = gp + off5*4，gp = x3，启动时指向 small-data 段；
- lwpc：地址 = pc + off5*4，编译器把 32 位常量/字符串地址放进 124 B 内的 literal pool。

这个 block 替换了原来的三地址 add/sub。GP 解决 .L_MergedGlobals/Int_Glob 一类全局变量；PC-relative literal 解决 Dhrystone 里大量 .L.str 字符串地址，避免每条地址都 li32（16-26 B）。

## 8. 融合分支（f4=5,6,7）

### c.bne / c.blt（f4=5,6）

    word = (f4 << 12) | (rs1_3 << 9) | (rs2_3 << 6) | (off4 << 2) | 0b11

- rs1_3/rs2_3 是 x8-x15；
- off4 是 4-bit 有符号，按 2 字节缩放，target = pc + sext(off4) * 2，范围 -16..+14 字节；
- c.bne：if (rs1 != rs2) pc = target；
- c.blt：if (signed rs1 < signed rs2) pc = target；
- c.bge rs1, rs2, L 由 c.blt rs2, rs1, L 实现（汇编器 alias）。

### c.blez（f4=7）

    word = (7 << 12) | (rs_3 << 9) | (off7 << 2) | 0b11

- rs_3 是 x8-x15；
- off7 是 7-bit 有符号，按 2 字节缩放，范围 -128..+126 字节；
- c.blez：if (signed rs <= 0) pc = target。

### 未融合的条件

- beq：不在 ISA 里，展开为 xor + c.beqz（4 B）；
- bgeu/bltu/bge：用 sltu/slt + c.beqz/c.bnez（6 B）；
- 如果 off4/off7 越界，汇编器在目标附近放 c.j trampoline（2 B）。

## 9. LD/ST（f4=8）

    word = (8 << 12) | (funct2 << 10) | (reg << 6) | (base << 4) | (off2 << 2) | 0b11

- funct2：0 lw，1 sw，2/3 reserved；
- reg 是 x0-x15（包括 ra=x1）；
- base：0=fp/x8，1=dp/x9，2=sp/x2，3=gp/x3；
- off2：0-3，按访问宽度缩放；字访问窗口 0-12 B。

字节/半字访问使用 Zcb：

- c.lbu/c.lh/c.lhu/c.sb/c.sh，基址 x8-x15；
- sp/gp 基址的字节/半字暂不支持。

## 10. M（f4=4）

    word = (4 << 12) | (funct3 << 9) | (rd3 << 6) | (rs2_3 << 3) | 0b11

funct3：0 reserved（c.mul 是 Zcb），1 mulh，2 mulhsu，3 mulhu，4 div，5 divu，6 rem，7 remu。rd3/rs2_3 是 x8-x15；除零/溢出语义同 RVM16-A。

## 11. F32（f4=9..13）

    word = (f4 << 12) | (funct2 << 10) | (fd << 6) | (fs2 << 2) | 0b11

fd/fs2 是 4-bit（f0-f15）。沿用 20 条 F32：

| f4 | funct2 | 指令 |
|---|---|---|
| 9 | 0-3 | fadd/fsub/fmul/fdiv |
| 10 | 0-3 | fsqrt/fmin/fmax/fsgnj |
| 11 | 0-1 | fsgnjn/fsgnjx |
| 11 | 2-3 | feq/flt |
| 12 | 0 | fle |
| 12 | 1-3 | fcvt.s.w/fcvt.w.s/fclass |
| 13 | 0-1 | fmv.x.w/fmv.w.x |
| 13 | 2-3 | flw/fsw（fd4 + base2 + off2） |

无 FMA；动态 frm。fcmp 写 fd 字段指定的 4-bit 寄存器（x0-x15）；编译器应选
x8-x15，这样结果可以直接喂给融合分支。x7 只用于冷 CSR 地址，不与 fcmp 混用。

## 12. CSR（f4=14）

    word = (14 << 12) | (csr4 << 8) | (reg4 << 4) | (op2 << 2) | 0b11

op2：0 csrr，1 csrw，2 csrs，3 csrc；reg4 是 x0-x15。

csr4=0 冷路径：12-bit CSR 地址在 x7（不是 x31）；csr4=1-15 热 CSR 同 A。

## 13. SYS（f4=15）

    word = (15 << 12) | (imm10 << 2) | 0b11

imm10：0 ecall，1 ebreak，2 mret，3 wfi，4 fence，5 fence.i。

## 14. 伪指令与展开

| 伪指令 | 展开 | 字节 |
|---|---|---:|
| mv rd, rs | c.mv（x0-x15） | 2 |
| li rd, imm6 | c.li | 2 |
| li rd, imm32 | 5-bit chunk 构造，8-13 条 | 16-26 |
| add rd, rs1, rs2 | 若 rd==rs1/rs2：2-address；否则 mv+2addr | 2-4 |
| lw/sw rd, off(gp) | c.lwgp/c.swgp，off 0..124 | 2 |
| lw rd, off(pc) | c.lwpc，off 0..124 | 2 |
| beq rs1, rs2, L | xor + c.beqz | 4 |
| bge rs1, rs2, L | c.blt rs2, rs1, L | 2 |
| bgeu/bltu | sltu + c.beqz/c.bnez | 6 |
| call L | c.jal L（RVC） | 2 |
| ret | c.jr ra | 2 |

## 15. Code size 预估

| 函数 | RVGC | RVM16-C | 变化 |
|---|---:|---:|---:|
| fir（指针循环，bne） | 32 | 30 | -6.3% |
| sum（blez + bne） | 24 | 20 | -16.7% |
| call（add + f，栈/ra） | 24 | 18 | -25% |
| index 循环（blt） | 待测 | 待测 | |
| 全局/外设访问 | 待测 | 待测 | 可能偏大 |

这些是手算预估，必须用 Spike/LLVM 原型验证。

## 16. 验证计划

1. Spike：ALU-12、GP-relative lw/sw、bne/blt/blez、LD/ST、M、CSR/SYS（F32 复用）；
2. LLVM MC：编码 + 分支 fixup（off4/off7 的 RVC 风格重定位）；
3. expand16：支持新编码和分支；
4. 基准：FIR、sum、memcpy、CRC、index 循环、状态机、全局访问；
5. 对比 RVGC、RV32EC+Zc*；
6. Go/no-go：geomean 比 RVGC 小 >=5-10%，最坏不超过 +5%；否则保留 A 作 negative result。

## 17. 与 Thumb / RVGC / RV32EC 的对比

- Thumb-1：16 GPR，低 8 个 r0-r7 用于 16 位形式；有 3-address ADD/SUB；用 flags + Bcc 做条件分支。
- RVM16-C：16 GPR，低 8 个 x8-x15 用于分支；GP-relative lw/sw；no-flags，用融合 bne/blt/blez。
- RVGC：32 位三地址 + RVC；code size 基准。
- RV32EC+Zc*：16 GPR + Zcmp/Zcmt；RVM16-C 的直接竞争对手，工具链成熟。

## 18. 风险与备选

- 16 GPR 仍会 spill；
- 分支 off4 只有 ±16 B，长循环要 trampoline；
- GP-relative 只有 252 B 窗口，超出要 bump gp 或用 li32；
- 没有 beq 融合，beq 4 B；
- beq/bgeu/bltu 仍是 compare+branch；
- ABI/LLVM CC/libc 是工具链级工作；
- 备选：8 GPR + 更多三地址（B），或 16 GPR + flags（更像 Thumb，但破坏 no-flags）。

## 19. 当前状态

- 本文档：编码/ABI/验证计划草案；
- Spike-C：ALU-12、bne/blt/blez、GP/PC、LD/ST 已实现；FIR/sum 26/20，x8=70/10；
- LLVM C MC：挂在 +zc16q3 下，distinct mnemonics；分支偏移是 raw uimm，尚无 label fixup；
- 下一步：Dhrystone/CoreMark 的 MILP 下界、label fixup、完整 ABI/编译器。
