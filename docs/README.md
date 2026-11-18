# Documentation index

## Current

| Document | What it covers |
|---|---|
| RVM16-ISA-Manual.adoc | Normative manual, AsciiDoc book in RISC-V manual style (draft 0.5) |
| RVM16-C-Manual.adoc | RVM16-C proposal manual (AsciiDoc): 16 GPR, ALU-12, fused branches, GP/PC, F32, ABI |
| RVM16-C-Manual.html | Built HTML preview of the C manual |
| RVM16-C-Design.md | RVM16-C design notes and block rationale |
| RVM16-C-Evaluation.md | Dhrystone/CoreMark model, metrics, bounded conclusion |
| Zhihu-RVM16-C.md | Chinese article draft for RVM16-C |
| RVA-E16-ISA-Manual.md | Working Markdown notes; the .adoc is the normative text |
| RVA-E16-Q3-Allocation.md | 16-block Q3 allocation and field budgets |
| RVM16-vs-RV32E.md | Comparison with RV32E / RV32EC+Zc* |
| Q3-Vertical-Slice-Status.md | What works, what is broken, known issues |
| Zhihu-Article.md | Promotional article draft |

Build the HTML manual with:

    ./build.sh

Either the Ruby asciidoctor gem or the npm package @asciidoctor/cli can build
it; the .adoc source is the deliverable.  A prebuilt HTML preview is
committed as RVM16-ISA-Manual.html.

## Design notes

| Document | What it covers |
|---|---|
| RVA-E16-RVC-Q3-Encoding.md | Early RVC+Q3 format exploration |
| RVA-E16-CodeSize-Estimate.md | Analytical code-size estimate |

## Historical / separate variants

These are kept for context; they are not the current RVM16 spec.

| Document | Note |
|---|---|
| RVA-E16-Strict-ISA-Spec.md | Early 4-bit-opcode strict-16 proposal, superseded by RVC+Q3 |
| RVA-E-Profile-Proposal.md | RVA-E32 compatibility profile (parcel + 32-bit escape), separate |
| Zc16-Encoding-Spec.md | Zc16.M 16-bit multiply/divide forms for RVA-E32 |
| Compiler-Implementation-Guide.md | LLVM CompressPat guide for the RVA-E32 variant |
| Submission-Cover-Letter.md | RFC email draft for the earlier variant |
