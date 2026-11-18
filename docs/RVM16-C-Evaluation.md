# RVM16-C 评估（草案 0.1）

状态：C 核心原型已跑通；完整最优性证明和 Dhrystone/CoreMark 指标待补。

## 1. 已完成的原型

- Spike-C 位于 D:/dsh_workspace/spike-c，只复制源码，未动 /home/milo/spike-q3；
- 新增 C 核心指令：c.add/c.sub（ALU-12）、c.add3/c.sub3（三地址）、c.bne/c.blt/c.blez、c.lw/c.sw；
- 过滤器只允许这些 Q3 编码和 RVC；A 的 Q3 指令被过滤；
- FIR：x8=70，RC=0；sum：x8=10，RC=0；
- 函数体大小：FIR 26 B，sum 20 B。

## 2. 和 RV32EC+Zc* / RVGC 的初步对比

同一组 C 函数（clang -O2）：

| 内核 | RV32EC+Zc* | RVGC | RVM16-C | 对 EC |
|---|---:|---:|---:|---:|
| fir | 30 | 32 | 26 | -13.3% |
| sum | 24 | 24 | 20 | -16.7% |
| Dhrystone | 2508 | 2364 | 待测 | |

RV32EC+Zc* 用 rv32emc_zcb_zcmp_zcmt（E+M+C+Zc*）；RVGC 用 rv32gc。
Dhrystone 是 dhry_pack_1/2.c 的 .text 总和；RVM16-C 需要先把 RV32EC 代码映射到 C 编码，尚未完成。

观察：

- FIR/sum 的收益来自 bne/blez 融合 + 16 GPR 下指针在 x8/x9；不是三地址；
- Dhrystone 的 RV32EC+Zc* 比 RVGC 还大 6.1%（2508 vs 2364），说明 E+Zc* 并不是天然更小；
- C 要在 Dhrystone 上赢，需要模型验证，不能只看两个循环。

### 2.1 Dhrystone 静态统计（rv32emc_zcb_zcmp_zcmt）

pack_1：584 条指令，37 条栈访问（6.3%），88 条 lui/auipc（15.1%），6 条条件分支。

这是 C 的硬伤：C 没有 lui/auipc，每个全局地址要么 li32（8-13 条，16-26 B），要么 gp 相对（当前 off2 只有 4 B 窗口）。RV32EC 的 lui+addi 是 8 B；静态 88 处地址构造，C 会多出约 700-1600 B，Dhrystone 很可能超过 3000 B，输给 RV32EC 的 2508 B。

所以“C 在当前 block map 下最优”不成立；缺的是 GP-relative/literal pool。

### 2.2 GP/PC-relative 已加入

- f4=3 的三地址 block 已替换为 GP/PC-relative：funct2 + reg3 + off5；
- funct2：0=lwgp，1=swgp，2=lwpc；off5 0..124 B；
- GP 解决 .L_MergedGlobals/Int_Glob 一类全局变量；lwpc 解决 .L.str 字符串地址（literal pool）；
- Spike 测试：GP 加载 5/7，x8=12，RC=0；PC literal 加载 0x12345678，x8=0x12345678，RC=0；
- FIR/sum 不受影响，仍是 26/20，x8=70/10。

Dhrystone pack1 有 28 处 .L_MergedGlobals 和约 40 处 .L.str；GP 让前者从 ~12 B 降到 2 B，lwpc 让后者从 ~8 B 降到 2 B（加 pool）。粗略估计可省 300-400 B，C 可能从 2508 降到 2100-2200；需要模型确认。

### 2.3 静态模型结果（tools/model_c.py）

| benchmark | RV32EC+Zc* actual | RVM16-C model | delta |
|---|---:|---:|---:|
| Dhrystone pack1+2 | 2508 | 1906 | -24.0% |
| CoreMark core（5 个 .c） | 6398 | 6316 | -1.3% |

- Dhrystone 模型里 GP=28、字符串=53、其他 lui=7；加上外部 call stub（malloc/printf 等约 6 个，~120 B）后约 2026 B，仍比 2508 小 19%。
- CoreMark core 的 GP=0、字符串=32、栈访问 273 条；C 模型比 actual 小 1.3%（Zcmp 已计入），模型本身对 CoreMark actual 高估约 11%，所以真实值可能在 ±5-10%。
- Dhrystone 栈访问 37/598 = 6.2%；CoreMark 栈访问 273/2328 = 11.7%。
- 分支 trampoline：Dhrystone 7/12，CoreMark 46/80（按模型的距离/寄存器判断），每条 +2 B；CoreMark 的 matrix/list 分支较多，需要更精确的距离分析。
- 结论：GP/PC 让 Dhrystone 这类全局/字符串密集代码明显变小；CoreMark 这类栈/结构体密集代码大约持平，不能说普遍更小。
- Linpack：标准 linpackc.new 是 double 精度，RVM16-C 只有 F32，不能直接跑；需要 single-precision 端口，目前未构建。

模型不是编译器：actual 列已用 assemble 后的 .text 校准到 Dhrystone 2508；CoreMark actual 列直接取 clang 对象 .text，模型对 CoreMark 的指令尺寸仍有约 11% 高估，所以 CoreMark 的数字只作趋势参考。

### 2.4 LLVM 状态

- LLVM C MC 已实现，挂在 +zc16q3 下，用 distinct mnemonics（c.addc/c.bnec/c.lwgc/...）；
- FIR/sum 由 llvm-mc 汇编，函数 26/20 B，Spike-C 运行 x8=70/10；
- 分支 label fixup 已实现（fixup_riscv_zvmc_branch4/7），FIR/sum 用 .Lloop/.Lend 汇编；LD/ST 语法是 c.lwc rd, off, base；
- A 的 +zc16q3 仍可用（c.sll 编码 0x052f）。
- Zcmp 已实测：cm.push {ra,s0-s7}, -48 / cm.pop，Spike-C x10=7，RC=0。
- Zcf 编码已验证：c.flw/c.fsw/c.flwsp/c.fswsp 可由 llvm-mc（+zcf）汇编；运行时还需要 mstatus.FS 初始化。
- Zcmt 运行时已测：cm.jt 0-31 / cm.jalt 32-255；jvt=0x80000240（64B 对齐），cm.jt 0 跳到 target，RC=0。
- Zcd 未启用：标准 c.fld/c.fsd 编码保留给 D-capable 变体；F32 profile 不定义它们，也不冲突。

## 6. 有界结论（当前）

- C 在 Dhrystone 模型上比 RV32EC+Zc* 小 19-24%；CoreMark 小 1.3%（模型误差 ±5-10%，可视作持平）。
- 这不是全局最优证明：只比较了 C 与 RV32EC，没有 MILP 下界，也没有把 A/B 全量跑完。
- 能说的有界结论是：**在 16 GPR、2-address 为主、3 个融合分支、GP/PC-relative、RVC 不变的约束下，C 是已评估方案中对 Dhrystone 最好的；CoreMark 没有优势。**
- 真正的“最优”还需要 MILP + 指令频率，这是下一步。

### 6.1 Block-count 有界最优

tools/block_bound.py 在“mandatory FP/M/CSR/SYS/LDST 之外还有 8 个自由 block”的模型下，枚举
ALU block、分支 block、GP/PC block、额外 LD/ST block 的分配，按指令频率算字节成本。

结果：C 的分配 (ALU=3, branch=3, GP=1, LD/ST=1) 在全部 7 个文件
（Dhrystone pack1/2、CoreMark 5 个 .c）上都是最优：

| 文件 | best | C |
|---|---:|---:|
| dhry_pack_1 | 460 | 460 |
| dhry_pack_2 | 64 | 64 |
| core_main | 286 | 286 |
| core_list_join | 512 | 512 |
| core_matrix | 412 | 412 |
| core_state | 212 | 212 |
| core_util | 52 | 52 |

这是一个**有界**结果：只证明 block 数量分配在这组频率模型下最优，没有证明 opcode
字段/格式的全局最优；完整的 MILP 仍未做。

### 2.5 Baseline benchmark runs

- Dhrystone：代码按 rv32emc_zcb_zcmp_zcmt 编译，在标准 Spike 上以
  RV32IMC_Zcb_Zcmp_Zcmt 运行，RC=0；ELF .text 2206 B（含 crt0/stubs）。
- CoreMark：同样编译/运行，RC=0；ELF .text 6338 B。ITERATIONS=10，但
  time_in_secs 被 stub 成 10，只跑最小迭代；时序没有意义。
- 这两个是 **RV32EC+Zc* baseline 运行**，不是 RVM16-C 二进制；RVM16-C
  仍是第 2.3 节的静态模型。
- Linpack 是 double 精度，RVM16-C F32-only，未运行。

## 3. 待补指标

### 3.1 Spill 率

- 对 RV32EC+Zc* 和 C 分别统计：栈访问（lw/sw 基址 sp）占全部指令的比例；
- C 和 RV32EC 都是 16 GPR，但 C 的分支只能用 x8-x15，可能增加拷贝/溢出；
- 目标：C 的 spill 率不超过 RV32EC 的 +5%。

### 3.2 分支越界/trampoline 比例

- 统计 Dhrystone/CoreMark 中 bne/blt/blez 的距离分布；
- C 的 off4 范围 -16..+14 B，off7 范围 -128..+126 B；
- 超出的分支需要 c.j trampoline（+2 B）；
- 目标：trampoline 比例 < 5%。

### 3.3 全局访问

- 统计 lui/auipc 和全局符号访问；
- C 没有 lui/auipc，大地址要用 li32（8-13 条），全局访问可能显著变大；
- 目标：Dhrystone 全局访问开销 < RV32EC 的 +10%，否则 C 不成立。

### 3.4 CoreMark

- 拉取 eembc/coremark，编译 rv32emc_zcb_zcmp_zcmt 和 rv32gc；
- 测 .text、spill、分支距离、全局访问；
- 把 RV32EC 指令映射到 C 编码，给出 C 的模型大小。

## 4. 最优性证明的方法

严格证明“C 是编码最优”需要把设计空间形式化：

1. 从 benchmark 统计指令类频率 f_i；
2. 对每类指令，列出可用的编码方案（2-address、3-address、融合分支、RVC 等）及字节成本；
3. 设 16 个 f4 block 和字段宽度为约束，设每种方案占用的 block 数为变量；
4. 目标：最小化 sum(f_i * cost_i)；
5. 用 MILP/CP-SAT 求解，得到下界；
6. 把 C 的实际分配代入，若等于下界，则在该模型内最优；否则给出 gap。

这不是“所有可能 ISA”的证明，而是“给定指令集候选和 block 约束”的最优性证明；需要在论文/文档里写清楚边界。

## 5. 当前结论

- C 在两个小循环上确实比 RV32EC+Zc* 小 4 B（13-17%）；
- 但这还不足以证明 Dhrystone/CoreMark 也小；
- 下一步必须做 3.1-3.4 的测量和 4 的 MILP，否则“最优”只是局部结论。
