require_extension(EXT_ZC16);
reg_t rd = insn.q3_ci_rd();
WRITE_REG(rd, READ_REG(rd) ^ insn.q3_ci_imm());
