# 当 RISC-V 只剩 16 位：给嵌入式场景的 RVM16 提案

这是一个可运行的提案，不是已定稿的标准。文中的 code size 数据来自手写内核和当前汇编器原型；C 编译器的 Expand16 还在做。

## 一、嵌入式为什么在意 code size

在 RISC-V 社区里，code size 从来不是“优化项”，而是嵌入式的硬指标：

- MCU 的 Flash 常常只有 64 KB、128 KB，SRAM 更小；
- RVC（C 扩展）把常用指令压到 16 位，已经是标准做法；
- RV32E 把寄存器堆砍到 16 个，Zc* 继续压缩常见序列；
- CoreMark/Dhrystone 的 code size 经常和性能一起被拿来做选型。

但这些方案都还是“32 位指令 + 16 位压缩”的混合体。只要遇到一个压不动的 32 位指令，取指带宽和 Flash 占用就回到 4 字节。对极端嵌入式来说，能不能整条指令流都是 16 位？

这就是 RVM16（工作名 RVA-E16）的出发点：把 RV32IMF 重新编码成严格的 16 位 ISA，最坏情况下用两条 16 位指令拼出一个 32 位操作。

## 二、设计：RVC 不动，11 象限变成 Q3

RISC-V 的 16 位编码有 4 个象限：

- 00/01/10 是 RVC，已经用掉；
- 11 在标准里是 32 位指令的入口。

RVM16 保留 00/01/10 的 RVC 逐字节不变，把 11 象限改成一个新的 Q3 空间：14 个 payload bit，16,384 个 pattern，按 f4 分成 16 个 block。这样：

- 纯 RVC 的二进制仍然能跑；
- 标准 RV32IMAF_C 的二进制（含 32 位指令）不能直接跑，需要重编译；
- Q3 里放两地址 ALU、M、load/store、F32、CSR、system。

寄存器：32 个 GPR（x31 保留 scratch），F32 必选，Q3 FP 用 f0–f15 共 16 个寄存器；两地址、动态 frm、不做 FMA（编译器展开成 fmv+fmul+fadd）。

## 三、工具链现状

目前已经有的：

- LLVM MC：c.sll/c.srl/c.sra/c.slt/c.sltu/c.xori/c.lw/c.sw，以及 20 条 F32（c.fadd.s … c.fsw），都能汇编出正确编码；
- Spike：同一批 Q3 指令能执行，F32 的 fadd/fsqrt/fcvt/flw/fsw 已经在 Spike 上跑通；
- 反汇编：llvm-mc -disassemble 能解 f4 0–8 的 Q3（ALU、xori、lw/sw），FP 反汇编还在补；
- 端到端：LLVM 汇编 → ELF → Spike → HTIF 退出 0。

## 四、Code size 实测（手写内核）

先说明：C 的 Expand16 还没完成，下面是手写汇编的同逻辑对比，不是 CoreMark 数据。RV32 侧用 llvm-mc -mattr=+c,+m,+f，Q3 侧用 +c,+f,+zc16q3，取 .text 大小。

| 小程序 | RV32IMAF_C | RVM16 | 降幅 |
|---|---:|---:|---:|
| ALU（sll/mul/slt/xori + 退出） | 42 B | 30 B | 28.6% |
| FP（1.0+1.0、fcvt、退出） | 42 B | 36 B | 14.3% |
| FP（fsw/flw/fsqrt/fcvt + 退出） | 56 B | 50 B | 10.7% |

注：FP 行的 RV32 数字不含启动时的 mstatus.FS 初始化（csrs 序列 6 B）；Q3 侧目前也没有做 FS 初始化。

几个观察：

- 纯 ALU 程序收益最大，因为 32 位的 sll/mul/slt/xori 都变成了单条 Q3；
- FP 程序收益小一些，因为 RV32 侧已经大量使用 RVC，Q3 的 FP 又是两地址，某些 move 省不掉；
- 程序越小，固定开销（构建常量、退出序列）占比越高，降幅会被稀释。等 Expand16 做完，跑 CoreMark/Dhrystone 才能给出有说服力的数字。

## 五、跑起来是什么样

Q3 程序在 16 位 Spike 上：

    $ spike --isa=RV32IFC_Zc16 --pc=0x80000000 fp.elf
    RC=0
    0x8000000e (0xd417) c.fmv.w.x f0, t0
    0x80000010 (0x9003) c.fadd.s  f0, f0
    0x80000012 (0xc82f) x11 0x00000002

1.0 + 1.0 = 2，fcvt.w.s 写回 a1=2。

对应的 RV32IMAF_C 程序在标准 Spike 上同样 RC=0。FP 程序在 RV32 侧需要先 csrs mstatus 打开 FS；Q3 侧目前是 PoC 的直接写 FPR，正式实现也要处理 FS/CSR。

| 程序 | RV32IMAF_C | RVM16 |
|---|---|---|
| ALU | RC=0 | RC=0 |
| FP | RC=0（需 FS init） | RC=0，a1=2 |
| FP3 | RC=0 | RC=0，a1=2 |

## 六、定位：16-bit 留给嵌入式，RVA profile 把 RVV 增强成领域形态

我的建议是：RVA23 之后的 application profile 不必再吸收这套纯 16-bit 编码。

原因很直接：

- application profile 要保证二进制兼容、标准工具链、操作系统支持；纯 16-bit 会把 32 位指令流全部作废；
- RVA23+ 的增量应该留给性能、向量、虚拟化这些方向；
- 16-bit 的试验更适合放在 M 系列/嵌入式，或者厂商扩展空间。

对 RVA profile，我的建议正好相反：不要再把 RVV 继续做大做全、让它承担所有 profile 的兼容包袱；而是把 RVV 增强成我们之前那种形态——保持标准 RVV 编码，增量加 vexp2.vv、vfbdota.vv 这类领域指令，让每个 profile 按需选用。这样 RVV 不必为了兼容所有场景越加越难受，领域指令也能按需下沉。

RVM16 和这套 RVV 改造共用的是方法论：标准编码不动、只加新 opcode、先在 LLVM/Spike 跑通、再谈标准化；但 RVM16 本身是标量 16 位，不是 RVV 的一部分，也不应该塞进 RVV。

换句话说：16-bit 留给嵌入式；RVA profile 的增量，应该把 RVV 增强成领域形态，而不是让 RVV 背更多标准包袱。

## 七、还没做完的

- Expand16：目前有一个独立翻译器原型，能把 clang 的小整数函数展开成 Q3（f(3,4)=59，以及数组求和的循环 sum=10，都已在 Spike 上验证）；LLVM post-RA pass 还没接；
- CoreMark/Dhrystone 的 code size 对比；
- FP 反汇编、Q3 的 M/CSR/SYS 块；
- base 寄存器顺序、load/store 偏移单位这些 PoC 细节；
- Spike/LLVM 的补丁整理成可提交的 patch。

## 八、代码与文档

- 指令集手册：rva-e/docs/RVA-E16-ISA-Manual.md
- Q3 分配：rva-e/docs/RVA-E16-Q3-Allocation.md
- LLVM 补丁：rva-e/patches/llvm/0002-RISCV-Q3-MC.patch
- 状态与已知问题：rva-e/docs/Q3-Vertical-Slice-Status.md

如果你也在做嵌入式 RISC-V 的 code size，欢迎拿 CoreMark/Dhrystone 来拍砖；尤其是“纯 16-bit 到底值不值得”这个问题，数据比立场重要。
