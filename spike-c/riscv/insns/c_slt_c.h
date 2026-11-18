WRITE_REG(insn.q3c_rd4(), ((int32_t)READ_REG(insn.q3c_rd4()) < (int32_t)READ_REG(insn.q3c_rs2_4())) ? 1 : 0);
