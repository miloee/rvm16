require_extension(EXT_ZC16);
reg_t rd = insn.q3_ca_rd();
reg_t rs2 = insn.q3_ca_rs2();
WRITE_REG(rd, READ_REG(rd) * READ_REG(rs2));
