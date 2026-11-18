# Documentation index

## Current

| Document | What it covers |
|---|---|
| RVM16-ISA-Manual.adoc | Normative manual, AsciiDoc book in RISC-V manual style (draft 0.4) |
| RVA-E16-ISA-Manual.md | Working Markdown notes; the .adoc is the normative text |
| RVA-E16-Q3-Allocation.md | 16-block Q3 allocation and field budgets |
| RVM16-vs-RV32E.md | Comparison with RV32E / RV32EC+Zc* |
| Q3-Vertical-Slice-Status.md | What works, what is broken, known issues |
| Zhihu-Article.md | Promotional article draft |

Build the HTML manual with:

    ./build.sh

This requires asciidoctor; the .adoc source is the deliverable.

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
