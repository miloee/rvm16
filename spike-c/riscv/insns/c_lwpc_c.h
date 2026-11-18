require_extension(EXT_ZC16);
reg_t addr = pc + insn.q3c_gp_off() * 4;
WRITE_REG(insn.q3c_gp_rd(), MMU.load<int32_t>(addr));
