require_extension(EXT_ZC16);
if ((int32_t)READ_REG(insn.q3c_blez_rs()) <= 0) {
  int32_t off = (int32_t)(insn.q3c_blez_off() << 25) >> 25;
  set_pc_and_serialize(pc + off * 2);
}
