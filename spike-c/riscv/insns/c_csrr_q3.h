require_extension(EXT_ZC16);
reg_t addr = q3_csr_addr(insn, READ_REG(7));
int csr = validate_csr(addr, false);
reg_t old = p->get_csr(csr, insn, false);
WRITE_REG(insn.q3_csr_reg(), sext_xlen(old));
