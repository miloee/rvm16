require_extension(EXT_ZC16);
require_extension('M');
reg_t rd = insn.q3_ca_rd();
reg_t rs2 = insn.q3_ca_rs2();
reg_t lhs = zext32(READ_REG(rd));
reg_t rhs = zext32(READ_REG(rs2));
if (rhs == 0)
  WRITE_REG(rd, UINT64_MAX);
else
  WRITE_REG(rd, sext32(lhs / rhs));
