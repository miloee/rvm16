# RVM16-C 设计草案

状态：方向已确认，编码草案；RVM16-A（32 GPR）保留为 negative control。

## 目标与约束

- 兼容 RVC：quadrant 00/01/10 逐字节不变，只有 quadrant 11 是 Q3 扩展；
- no-flags：不引入条件码，用融合比较分支；
- 16 个架构 GPR（x0-x15），x0/x1/x2 特殊，x8-x15 是 16 位 ALU/分支的主要数据寄存器；
- 2-address ALU 为主，额外给 add/sub 一个三地址 block；
- 目标：嵌入式 C 的 code size 比 RVGC 小一些（geomean 5-10%），不是所有函数都小。

## RVC baseline

“RVC 不变”需要写死具体基线，因为 RVC 本身也在扩：

- **C v2.0**：quadrant 00/01/10 的编码逐字节不变；
- **Zcb 必选**：c.mul、c.lbu、c.lh、c.lhu、c.sb、c.sh、c.zext.b/h/w、c.sext.b/h、c.not，使用标准 Zcb 编码；RVM16-C 的字节/半字就靠它；
- **Zcmp/Zcmt 可选**：如果启用，push/pop 和 table jump 也用标准编码，RVM16-C 不重新定义；
- RVM16-C 的 Q3 助记符虽然带 c. 前缀，但编码全在 **quadrant 11**，没有改任何 00/01/10 的 RVC 编码；
- RVC 中寻址 x16-x31 的形式（例如 c.lwsp rd=x20）在 16 GPR 模型下是非法/保留。

所以准确说法是：**RVC 的 00/01/10 一个 bit 都不改；Zcb（以及可选的 Zcmp/Zcmt）是继承的标准指令，不是我们新加的；我们新加的只有 quadrant 11 的 Q3。**

## 寄存器模型

| 寄存器 | 角色 |
|---|---|
| x0 | zero |
| x1 | ra |
| x2 | sp |
| x3 | gp（可选） |
| x4 | tp（可选） |
| x8-x15 | 数据寄存器；a0-a5 = x8-x13，s0/s1 = x14/x15 |

x16-x31 不存在；RVC 中引用 x16-x31 的编码在 RVM16-C 里是保留/非法。

## Q3 block map（f4，16 个）

| f4 | 用途 | 编码 |
|---|---|---|
| 0 | ALU-12 A | funct2 + rd4 + rs2_4：add/sub/and/or |
| 1 | ALU-12 B | funct2 + rd4 + rs2_4：xor/sll/srl/sra |
| 2 | ALU-12 C | funct2 + rd4 + rs2_4：slt/sltu + 2 reserved |
| 3 | 三地址 | funct1 + rd3 + rs1_3 + rs2_3：add/sub |
| 4 | M | funct3 + rd3 + rs2_3：mulh/mulhsu/mulhu/div/divu/rem/remu |
| 5 | c.bne | rs1_3 + rs2_3 + off4 |
| 6 | c.blt | rs1_3 + rs2_3 + off4；bge 交换 rs1/rs2 |
| 7 | c.blez | rs_3 + off7 |
| 8 | LD/ST | funct2 + reg4 + base2 + off2：lw/sw + 2 reserved |
| 9-13 | F32 | funct2 + fd4 + fs2_4，20 条 |
| 14 | CSR | csr4 + reg4 + op2 |
| 15 | SYS | imm10 |

### ALU-12（f4=0..2）

每个 block 4 条，2-address：

    payload = (funct2 << 8) | (rd << 4) | rs2
    word    = (f4 << 12) | payload | 0b11

rd/rs2 是 4-bit（x0-x15）。f4=0 的 funct2：0 add, 1 sub, 2 and, 3 or；f4=1：0 xor, 1 sll, 2 srl, 3 sra；f4=2：0 slt, 1 sltu, 2/3 reserved。

### 三地址（f4=3）

    payload = (funct1 << 9) | (rd' << 6) | (rs1' << 3) | rs2'
    word    = (3 << 12) | payload | 0b11

rd'/rs1'/rs2' 是 3-bit（x8-x15）；funct1：0 add, 1 sub。一个 block 只有 2 条，这是 3-bit 字段的代价。

### 融合分支（f4=5,6,7）

c.bne / c.blt：

    payload = (rs1' << 7) | (rs2' << 4) | off4
    word    = (f4 << 12) | payload | 0b11

off4 是 4-bit 有符号，按 2 字节缩放，范围 -16..+14 字节。

c.blez：

    payload = (rs' << 7) | off7
    word    = (7 << 12) | payload | 0b11

off7 是 7-bit 有符号，按 2 字节缩放，范围 -128..+126 字节。

bge rs1,rs2,L 由 c.blt rs2,rs1,L 实现；beq 不在 ISA 里，用 xor + c.beqz（4 B）。

### LD/ST（f4=8）

    payload = (funct2 << 8) | (reg << 4) | (base << 2) | off2
    word    = (8 << 12) | payload | 0b11

funct2：0 lw, 1 sw, 2/3 reserved。reg 是 4-bit（x0-x15），base 是 2-bit（0=fp/x8, 1=dp/x9, 2=sp/x2, 3=gp/x3），off2 按访问宽度缩放（字 0-3，4 B 窗口）。

字节/半字访问用 Zcb 的 c.lbu/c.lh/c.lhu/c.sb/c.sh（x8-x15 基址）；sp/gp 基址的字节/半字暂不支持。

### F32（f4=9..13）

沿用 RVM16-A 的 20 条 F32，funct2 + fd4 + fs2_4，16 个 FP 寄存器 f0-f15；flw/fsw 用 funct2=2/3，fd4 + base2 + off2（4 B 窗口）。

### CSR / SYS（f4=14,15）

CSR 沿用 csr4 + reg4 + op2；csr4=0 的冷路径用 x7 作为地址寄存器（x31 不存在）。

SYS 沿用 imm10：ecall/ebreak/mret/wfi/fence/fence.i。

## ABI（RVM16-C）

- 整数/指针参数 a0-a5 = x8-x13；返回 a0/a1 = x8/x9；
- 前两个指针参数自然落在 x8/x9，正好是 Q3 base 寄存器；
- F32 参数 f0-f7，返回 f0；f8-f15 callee-saved；
- s0/s1 = x14/x15 callee-saved；
- sp = x2，ra = x1，gp/tp 可选；
- 栈 16 B 对齐；
- 分支操作数必须在 x8-x15；编译器负责把分支用的值放在低 8 个。

## 预估 code size

| 函数 | RVGC | RVM16-C |
|---|---:|---:|
| fir（指针循环，bne） | 32 | 30（-6.3%） |
| sum（blez + bne） | 24 | 20（-16.7%） |
| index 循环（blt） | 待测 | 待测 |
| 全局/外设访问 | 待测 | 可能偏大 |

这些是手算预估，必须用 Spike/LLVM 原型验证。

## 实现顺序

1. Spike：ALU-12、三地址 add/sub、bne/blt/blez、LD/ST、M、CSR/SYS（F32 复用）；
2. LLVM MC：编码 + 分支 fixup（off4/off7 的 RVC 风格重定位）；
3. 扩展 expand16 翻译器：支持新编码和分支；
4. 基准：FIR、sum、memcpy、CRC、index 循环、状态机、全局访问；对比 RVGC 和 RV32EC+Zc*；
5. Go/no-go：geomean 比 RVGC 小 >=5-10%，最坏不超过 +5%。

## 开放问题

- 三地址只有 add/sub，是否够；
- LD/ST 只有 lw/sw，字节/半字依赖 Zcb；
- 没有 GP-relative 大偏移，全局访问可能偏大；
- 分支 off4 只有 ±16 B，长循环需要 trampoline；
- beq 没有融合，仍是 4 B；
- x7 冷 CSR 路径与 ABI 的冲突；
- RVC 中 x16-x31 指令在 16 GPR 下的非法处理。
