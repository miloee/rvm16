require_extension(EXT_ZC16);
reg_t rd = insn.q3_rd();
reg_t rs2 = insn.q3_rs2();
WRITE_REG(rd, READ_REG(rd) << (READ_REG(rs2) & (xlen - 1)));
