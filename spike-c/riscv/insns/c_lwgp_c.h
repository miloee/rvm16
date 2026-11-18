require_extension(EXT_ZC16);
reg_t addr = READ_REG(3) + insn.q3c_gp_off() * 4;
WRITE_REG(insn.q3c_gp_rd(), MMU.load<int32_t>(addr));
