require_extension(EXT_ZC16);
require_either_extension('M', EXT_ZMMUL);
reg_t rd = insn.q3_ca_rd();
reg_t rs2 = insn.q3_ca_rs2();
WRITE_REG(rd, sext32((sext32(READ_REG(rd)) * reg_t((uint32_t)READ_REG(rs2))) >> 32));
