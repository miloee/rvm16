require_extension(EXT_ZC16);
require_extension('M');
reg_t rd = insn.q3_ca_rd();
reg_t rs2 = insn.q3_ca_rs2();
sreg_t lhs = sext32(READ_REG(rd));
sreg_t rhs = sext32(READ_REG(rs2));
if (rhs == 0)
  WRITE_REG(rd, sext32(lhs));
else if (lhs == INT32_MIN && rhs == -1)
  WRITE_REG(rd, 0);
else
  WRITE_REG(rd, sext32(lhs % rhs));
