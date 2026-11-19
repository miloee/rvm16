# 把 RISC-V 压到 16 位：RVM16-C 的完整探索

> 一句话结论：RVM16-C 在 FIR/sum 上实测更小，Dhrystone 模型小 19–24%，CoreMark 约持平；它不是通用 C 的 code-size 银弹，而是“RVC 兼容、面向 code-size 敏感场景”的一个独立 profile 提案。

## 1. 背景：code size 为什么又回到桌面

x86 靠变长指令（1–15 B）换 code density，代价是取指/解码复杂；ARM 的 Thumb 用 16 位子集，再用 Thumb-2 的 32 位指令做逃生口；RISC-V 的 RVC 则是“32 位基座 + 16 位压缩”，常用指令变短，但 32 位指令始终存在。

RVA 系列 application profile 把 C 作为基本组成之一，解决的是“应用处理器也要 code size”的问题。但在更小的嵌入式场景里，RVC 仍然不够：prologue/epilogue、全局地址、字符串地址、常量池、分支，仍然会落回 32 位指令。

我的判断是：**不应该去改 RVA，也不应该要求所有 RISC-V 都变成 16 位；应该给 code-size 敏感场景一个额外的 profile。** RVM16-C 就是这个 profile 的提案：保留 RVC 的 quadrant 00/01/10，一个 bit 都不改；把 quadrant 11 重定义成新的 16 位空间；所有指令都是 16 位，没有 32 位逃生口。

## 2. 起点：RVM16-A，32 个 GPR

最早做的是 RVM16-A：32 个 GPR，FLEN=32，16 个 f4 block，仍然严格 16 位；32 GPR 是作为对照。A 有完整的手册、Spike 实现和 LLVM MC。

但 32 GPR 的方案里，编码空间很快不够用：rd/rs1/rs2 各 5 位就是 15 位，只剩 1 位做 opcode；要么牺牲 block 数，要么牺牲寻址模式。A 能跑，但它没有回答“16 位里怎么把 C 写小”这个问题。

## 3. 第一次大转向：32 → 16 GPR

真正做 C 时，我先把寄存器数量从 32 降到 16：

- x0–x15，x16–x31 不存在；
- RVC 中任何寻址 x16–x31 的形式都非法；
- FP 也只保留 f0–f15。

中间认真考虑过 8 GPR：如果 16 个放不下，就退到 8 个。但 8 个 GPR 的 spill/ABI 代价太大，最后选了 16 个——刚好让 4 位 rd/rs2 和三地址/GP/PC 的字段都能放下。

这一步是后面所有编码的前提：**寄存器数量不是“保持不变”，而是从 32 降到 16。**

## 4. 编码：三地址试过，最后放弃

一开始我问过“三地址是不是最好有”，也真的加了 c.add3/c.sub3 的原型。结论是：三地址在 16 位里太贵。

- 三地址要 rd/rs1/rs2 三个 4 位字段，再加 f4/funct，block 很快被吃满；
- 两地址 rd = rd op rs2 加融合分支，已经能把大多数 C 表达式压到 2 B；
- 三地址没有带来可观测的 code-size 收益，反而让 block 分配变紧。

最终 ALU 是 12 条两地址指令：add/sub/and/or/xor/sll/srl/sra/slt/sltu。三地址原型保留在早期实验里，但没有进入最终 ISA。

16 个 f4 block 的分配：

| f4 | 用途 |
|---|---|
| 0–2 | ALU-12 |
| 3 | GP/PC：lwgp/swgp/lwpc |
| 4 | M：mulh/mulhsu/mulhu/div/divu/rem/remu |
| 5–7 | c.bne / c.blt / c.blez |
| 8 | lwc/swc |
| 9–13 | F32 |
| 14 | CSR |
| 15 | SYS |

![图 1 RVM16-C block map](figs/rvm16c-blockmap.png)

*图 1：quadrant 11 的 16 个 f4 block。RVC 的 00/01/10 不变。*

## 5. 指令集成形

- **no-flags**：不引入条件码，用 c.bne/c.blt/c.blez 融合比较和分支；beq 展开成 xor + c.beqz，bge 用交换操作数的 blt。
- **GP/PC-relative**：lwgp/swgp 用 gp=x3 访问小全局，lwpc 从 PC 附近取字符串地址/常量池；off5 0–124 B。
- **LD/ST**：lwc/swc，base 只有 x8/x9/sp/gp 四种，off2 按访问宽度缩放。
- **M**：mulh/mulhsu/mulhu/div/divu/rem/remu；c.mul 走 Zcb。
- **F32**：16 个 FP 寄存器，20 条指令，无 FMA；fcmp 没有 rd 字段，固定写 x7，再由编译器搬到 x8–x15。
- **CSR/SYS**：csrr/csrw/csrs/csrc；ecall/ebreak/mret/wfi/fence/fence.i。
- **Zc**：Zca 继承；Zcb、Zcmp、Zcf 必选；Zcmt 对 M/F 可选、对 E profile 必选；Zcd 编码保留给未来的 D 变体；Zcmop 没有加入。
- **Zcmp save-all**：cm.push {ra,s0-s7}, -48 / cm.pop，2 B prologue/epilogue；16 GPR 下会多保存 x8–x15，这是有意的取舍。

Zcb 里有两个容易忽略的依赖：c.sext.b/h 需要 Zbb；c.zext.w 在 RV32 需要 Zba。它们不是无条件可用的，手册里已经写成 optional。

## 6. Spike 原型：从“能跑”到“跑对”

Spike-C 是改过的 Spike：insn_length=2，32 位 opcode 被过滤，quadrant 11 的 block 走新的 insn。

最早只跑 FIR/sum：

- FIR 26 B，x8=70；
- sum 20 B，x8=10。

后面一块块补：

- 分支 bne/blt/blez；
- GP/PC：lwgp/swgp/lwpc；
- LD/ST：lwc/swc；
- Zcmp：cm.push/pop，x10=7；
- Zcmt：jvt=0x80000240（64 B 对齐），cm.jt 0 跳转成功；
- Zcf：c.flw/c.fsw/c.flwsp/c.fswsp 编码验证。

再往后是整组测试：

- ALU-12 全 10 条；
- M 全 7 条；
- F32 全 20 条；
- CSR csrw/csrr/csrs/csrc；
- SYS ecall/ebreak/mret/fence/fence.i/wfi；
- Zcb 的 lbu/lh/lhu/sb/sh/zext.b/h/sext.b/h/not。

这里踩过的坑：

- Zcmt 测试一开始用 x31 传 CSR 地址；但 C 只有 x0–x15，x31 是非架构寄存器。后来把 cold CSR 路径改成 x7，测试也改成 x7。
- fcmp 在 A 里写 x31；C 里同样改成 x7。
- WFI 一开始不进 handler：mstatus 的 MIE、mtvec、mie、mtimecmp 要按顺序设；最后用 CLINT timer 跑通，handler 实际执行、wfi 返回。

## 7. LLVM MC：先解决“能编码”

完整后端没有做，先做 MC：

- +zc16q3 下独立助记符：c.addc/c.subc/c.andc/c.orc/c.xorc/c.sllc/c.srlc/c.srac/c.sltc/c.sltuc，c.bnec/c.bltc/c.blezc，c.lwgc/c.swgc/c.lwpc，c.lwc/c.swc；
- 分支 label fixup：fixup_riscv_zvmc_branch4/7；
- FIR/sum 用 .Lloop/.Lend 汇编，26/20 B，Spike 跑 70/10。

MC 阶段也踩了坑：操作数类型、HasStdExtZvmc、InstFormat、ELF relocation、branch offset 0 的 fixup，都是逐个补的。

## 8. 数据：哪些是实测，哪些是模型

| 内核 | RV32EC+Zc* | RVM16-C | 性质 |
|---|---:|---:|---|
| FIR | 30 B | 26 B | llvm-mc + Spike 实测 |
| sum | 24 B | 20 B | llvm-mc + Spike 实测 |
| Dhrystone | 2508 B | 1906 B（+stub ≈2026） | 静态模型 |
| CoreMark core | 6398 B | 6316 B | 静态模型 |
| Linpack | — | — | 只有 baseline float 端口，无 C 二进制 |

![图 2 code size 对比](figs/rvm16c-codesize.png)

*图 2：左为 FIR/sum 实测，右为 Dhrystone/CoreMark 静态模型。*

解释：

- Dhrystone 有 29 处 .L_MergedGlobals、53 处 .L.str；GP/PC 把地址构造从 8–12 B 降到 2 B，这是主要收益。
- CoreMark 是栈/结构体密集，GP=0，只有 32 处字符串；加入 Zcmp 后模型约 -1.3%，落在模型误差 ±5–10% 内，只能算**持平**，不能算更小。
- 栈访问：Dhrystone 6.2%，CoreMark 11.7%。
- 分支 trampoline：Dhrystone 7/12，CoreMark 46/80（模型判断）。

三个 benchmark 的实际运行是 **RV32EC+Zc* baseline**，不是 RVM16-C 二进制：

- Dhrystone：自检值全部正确，RC=0；
- CoreMark：seeds 0，CRC final 0x4983，“Correct operation validated”，RC=0；
- Linpack：single-precision 端口，n=50，KFLOPS 5.00，RC=0；clock 是确定性 stub，只证明端口和输出路径。

## 9. 全流程复盘

按阶段看，这个项目走过：

1. 最初想找 RVV 的修改流程，后来明确：这是标量 ISA，不是向量。
2. RVM16-A：32 GPR、FLEN=32、16 block，先证明“16 位编码空间”可行。
3. 转向 C：32 → 16 GPR；8 GPR 作为备选被否；F32 保留。
4. 编码探索：三地址 c.add3/c.sub3 原型 → 放弃；两地址 + 融合分支。
5. 指令集成形：ALU-12、bne/blt/blez、GP/PC、LD/ST、M、F32、CSR/SYS。
6. Zc 集成：Zca/Zcb/Zcmp/Zcf/Zcmt，Zcd 保留，Zcmop 不加。
7. Spike-C 原型：从 FIR/sum 到 ALU/M/F32/CSR/SYS/Zcb/WFI 全组测试。
8. LLVM MC：独立助记符、分支 fixup、FIR/sum 26/20。
9. 评估：静态模型、spill/trampoline/globals、block-count 有界最优。
10. benchmark：Dhrystone/CoreMark/Linpack 的 RV32EC+Zc* baseline 全部跑完。
11. 文档与仓库：先写手册再编码；按 RISC-V 社区 AsciiDoc 风格重写，补 WaveDrom 编码图；最后是知乎草稿和 GitHub。

## 10. 结论与讨论

**严格 16 位不是通用 C 的 code-size 银弹。**

- 指针/全局/字符串密集的代码，RVM16-C 能小 19–24%（Dhrystone 模型）；
- 栈/结构体密集的代码，约持平（CoreMark 模型 -1.3%，在误差内）；
- 没有 flags、没有 32 位逃生口，某些循环仍然要靠 compare+branch；
- 和 Thumb 比，RVM16-C 少了 flags 和 32 位 Thumb-2，多了 RVC 兼容；
- 和 RVC 比，它把“所有指令”都压到 16 位，代价是标准 32 位二进制不兼容。

如果目标是“所有嵌入式都更小”，这个方案不成立；如果目标是“在 RVC 兼容前提下，给 code-size 敏感场景一个独立 profile”，它是有数据、有 Spike、有 MC、有 benchmark 的提案。

## 讨论：想听到的反馈

1. 单独做一个 code-size profile，和“改 RVA/改 RVC”相比，是不是更合适的层次？
2. 16 GPR 够不够？如果退到 8 GPR，spill 和 ABI 的代价是否值得？
3. 没有 32 位逃生口，对性能/编译器的风险能不能接受？
4. Zbb/Zba 要不要进这个 profile？还是让 c.sext/c.zext.w 继续 optional？
5. 哪些真实 workload 最能说明“RVC 不够、但又不想上 Thumb-2”？

## 11. 代码与复现

- GitHub: https://github.com/miloee/rvm16
- Spike 分支: https://github.com/miloee/rvm16/tree/spike-c/spike-c
- tags: rvm16c-v0.1, spike-c-v0.1
- 手册: docs/RVM16-C-Manual.adoc / .html
- 评估: docs/RVM16-C-Evaluation.md
- 指令测试: bench/c/
- Linpack 端口: bench/linpack/
- LLVM MC patch: patches/llvm/0003-RISCV-Zvmc-MC.patch
- Spike patch: patches/spike-c/0001-spike-c-full.patch

复现入口：

    git clone https://github.com/miloee/rvm16
    cd rvm16/spike-c
    mkdir build && cd build
    ../configure --prefix=$PWD/install
    make -j20

## 12. 还没做的

- 完整 LLVM 后端/Clang ABI/libc：没有它，就没有 RVM16-C 的 C benchmark 二进制；
- RVM16-C 自己的 Dhrystone/CoreMark/Linpack：现在只有 RV32EC+Zc* baseline；
- RVC 全编码逐条枚举；
- MILP 全局最优性下界；
- Zbb/Zba 是否进入 profile 的最终决策；
- 面积/功耗/频率，而不只是 code size。

## 13. 相关工作与横向对比

| | RVC | RVM16-C | ARM Thumb-2 | x86 |
|---|---|---|---|---|
| 指令宽度 | 16 + 32 位 | 只有 16 位 | 16 + 32 位 | 1–15 B 变长 |
| 32 位逃生口 | 有 | 无 | 有 | 不适用 |
| GPR 数量 | 32 | 16 | 16（Thumb 状态） | 8/16 |
| 条件码/flags | 无 | 无 | 有（APSR） | 有 |
| 压缩 load/store | Zcf/Zcb | Zcf/Zcb | 有 | 不适用 |
| 典型 prologue | Zcmp | Zcmp | push/pop | push/pop |
| 二进制兼容 | RISC-V | 新 ISA | ARM | x86 |

这张表想说明的不是“谁更先进”，而是三者解决 code size 的层次不同：

- RVC 是“32 位基座 + 16 位压缩”，保留 32 位逃生口；
- Thumb-2 是“16 位为主 + 32 位扩展”，有 flags 和 32 位逃生口；
- x86 用变长指令换密度，代价是解码复杂；
- RVM16-C 是“全部 16 位、没有逃生口”，用兼容性换固定取指宽度。

## 14. 和 Thumb 比 code size

这是这篇文章最想讨论的点之一：**RVM16-C 在机制上是有资格和 Thumb 比 code size 的。**

原因不是“16 位就一定更小”，而是几个机制叠加：

- 所有指令 16 位，没有 32 位 fallback；Thumb-2 仍会在复杂寻址/大立即数时用 32 位；
- GP/PC-relative 把全局/字符串地址构造压到 2 B；
- c.bne/c.blt/c.blez 把 compare+branch 融合成 2 B；
- Zcmp 把 prologue/epilogue 压到 2 B；
- 16 GPR 让 rd/rs2 只要 4 位，给 funct/offset 留空间。

和 Thumb-2 比：

- Thumb-2 有 32 位指令、flags、更成熟的编译器，性能/代码结构更灵活；
- RVM16-C 没有 32 位逃生口，复杂操作要靠多条 16 位指令拼；
- RVM16-C 保留了 RVC 的 00/01/10，RVC 生态的编码习惯还在。

**边界**：目前没有“同一份 C、同一个优化级别、clang -mthumb vs RVM16-C”的实测。已有数据是 FIR/sum 对 RV32EC+Zc* 的实测，以及 Dhrystone/CoreMark 的模型。因此现在能说的是：

> RVM16-C 的目标是进入 Thumb 的 code-size 量级，机制上具备可比性；但“已经比 Thumb 小”需要同源 C 的实测，本文不宣称。

下一步应该做的对比实验：

1. 同一份 Dhrystone/CoreMark/Linpack C；
2. clang -O2 -mthumb 生成 Thumb-2 二进制；
3. RVM16-C 用 translator/后端生成二进制；
4. 比 .text、栈访问、分支数量、trampoline；
5. 同时记录 IPC/周期，避免只看 code size。

## 15. 接受/放弃判据

一个 code-size profile 不能只靠“看起来更小”。我建议用下面的判据决定是否继续：

- Dhrystone 比 RV32EC+Zc* 小 **≥15%**；
- CoreMark 不退化超过 **2%**；
- 同源 C 下，和 Thumb-2 的 code size 差距在 **±10%** 内；
- spill/reload 增量不超过 **5%**；
- 分支 trampoline 比例不超过 **2%**；
- 所有 benchmark 能编译、能跑、自检/CRC 通过。

如果 Dhrystone 收益低于 15%，或者 CoreMark 明显退化，这个 profile 就不值得单独存在；如果 Thumb 对比输得很明显，就应该回到 RVC/Zc 路线，而不是继续加指令。

## 16. 性能、面积、功耗

code size 只是第一维。16 位固定宽度的影响至少有三面：

- **取指**：16 位对齐，取指带宽和 cache 行利用率可能更好；
- **IPC**：没有 32 位逃生口，复杂操作要拆成多条 16 位指令，动态指令数可能上升；
- **面积/功耗**：16 GPR + 16 FP 寄存器比 32 GPR 小，但译码/控制逻辑和更多指令数可能抵消。

目前只有 code size 和功能测试，没有 IPC、频率、面积、功耗数据。下一步需要：

- RTL 或周期级模型，跑同样 workload；
- 统计动态指令数、取指字节、分支数；
- 对比 RV32EC+Zc* 和 Thumb-2 的 cycles/byte。

## 17. ABI 与工具链

16 GPR 不是“把 x31 删掉”这么简单：

- 调用约定要重新定义参数/返回值/callee-saved；
- varargs、结构体返回、浮点参数需要新 ABI；
- Zcmp 的 save-all 会多保存 x8–x15，要权衡；
- 链接器 relaxation、relocation、trampoline 要支持 16 位分支范围；
- 调试信息、unwinder、库、启动代码都要适配；
- 和 RVC 的兼容只到编码层，ABI 不兼容 32 GPR。

LLVM 目前只有 MC，没有 TargetMachine/CC/frame lowering/isel，所以还没有 RVM16-C 的 C 二进制。这是最大的工程缺口。

## 18. 形式化与验证

现在已经有的验证：

- 16 个 f4 block 的分配检查；
- Spike-C 的 filter/insn 测试；
- ALU/M/F32/CSR/SYS/Zcb/WFI 的期望值测试；
- FIR/sum、Zcmp、Zcmt、Zcf 的运行时测试。

还不够的：

- 每条指令的编码/解码形式化检查；
- RVC 00/01/10 与 Q3 的冲突/保留位检查；
- 随机指令差分测试（Spike vs 规范模型）；
- 链接器 relaxation/relocation 的边界测试；
- 形式化的“所有 16 位模式要么合法、要么明确非法”。

## 19. 真实 workload 与生态

Dhrystone/CoreMark 是微基准，不是产品代码。要证明这个 profile 有价值，需要：

- 真实嵌入式 C 代码的 code-size 分布；
- 按模块统计：全局/字符串、栈、分支、常量池；
- 和 RVC、Thumb-2 的同源 C 对比；
- 工具链/库/调试器/OS 的支持成本；
- 生态碎片化：多一个 ISA profile，编译器和库要不要多一套。

## 20. 安全

固定 16 位、没有 32 位逃生口，对安全的影响没有被研究：

- 固定宽度可能简化 decode，但不自动等于更安全；
- 没有 32 位指令，某些攻击面（长指令、非对齐）变化；
- ROP/JOP、CFI、指针完整性需要单独评估；
- 16 GPR 的寄存器压力可能增加栈 spill，影响泄漏面。

这些目前都只是问题，不是结论。

## 参考资料

- RISC-V specifications: https://riscv.org/technical/specifications/
- RISC-V profiles: https://github.com/riscv/riscv-profiles
- ARM instruction set architecture: https://developer.arm.com/Architectures/Instruction-Set-Architecture
- Intel SDM: https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
- 本仓库手册: docs/RVM16-C-Manual.adoc / .html
- 本仓库评估: docs/RVM16-C-Evaluation.md
