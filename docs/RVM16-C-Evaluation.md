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

### 2.2 GP-relative 已加入

- f4=3 的三地址 block 已替换为 GP-relative：funct1 + reg3 + off6，0..252 B，基址 gp=x3；
- 新增 c.lwgp/c.swgp；
- Spike 测试：gp=0x80000200，加载 5/7，x8=12，RC=0；
- FIR/sum 不受影响，仍是 26/20，x8=70/10。

Dhrystone 的 88 条 lui/auipc 里，落在 gp+252 B 的全局访问可以变成 2 B 的 lwgp/swgp；仍需模型确认能省多少。

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
