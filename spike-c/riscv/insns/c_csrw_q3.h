require_extension(EXT_ZC16);
reg_t addr = q3_csr_addr(insn, READ_REG(7));
int csr = validate_csr(addr, true);
p->put_csr(csr, READ_REG(insn.q3_csr_reg()));
serialize();
