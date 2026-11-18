require_extension(EXT_ZC16);
reg_t addr = q3_csr_addr(insn, READ_REG(7));
reg_t rs = READ_REG(insn.q3_csr_reg());
bool write = insn.q3_csr_reg() != 0;
int csr = validate_csr(addr, write);
p->get_csr(csr, insn, write);
if (write)
  p->put_csr(csr, p->get_csr_for_write(csr) & ~rs);
serialize();
