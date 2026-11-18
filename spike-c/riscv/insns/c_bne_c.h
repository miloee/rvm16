require_extension(EXT_ZC16);
if (READ_REG(insn.q3c_br_rs1()) != READ_REG(insn.q3c_br_rs2())) {
  int32_t off = (int32_t)(insn.q3c_br_off() << 28) >> 28;
  set_pc_and_serialize(pc + off * 2);
}
