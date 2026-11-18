require_extension(EXT_ZC16);
static const reg_t bases[4] = {8, 9, 2, 3};
reg_t rs2 = insn.q3_ls_reg();
reg_t addr = READ_REG(bases[insn.q3_ls_base()]) + insn.q3_ls_off() * 4;
MMU.store<uint32_t>(addr, READ_REG(rs2));
