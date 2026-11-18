require_extension(EXT_ZC16);
static const reg_t bases[4] = {8, 9, 2, 3};
reg_t addr = READ_REG(bases[insn.q3_ls_base()]) + insn.q3_ls_off() * 4;
WRITE_REG(insn.q3_ls_reg(), MMU.load<int32_t>(addr));
