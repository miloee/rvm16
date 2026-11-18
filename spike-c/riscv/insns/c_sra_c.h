WRITE_REG(insn.q3c_rd4(), (reg_t)((int32_t)READ_REG(insn.q3c_rd4()) >> (READ_REG(insn.q3c_rs2_4()) & 31)));
