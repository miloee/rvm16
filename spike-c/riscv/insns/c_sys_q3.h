require_extension(EXT_ZC16);
unsigned imm = insn.q3_sys_imm();
switch (imm) {
case 0:
  switch (STATE.prv) {
  case PRV_U: throw trap_user_ecall();
  case PRV_S:
    if (STATE.v) throw trap_virtual_supervisor_ecall();
    else throw trap_supervisor_ecall();
  case PRV_M: throw trap_machine_ecall();
  default: abort();
  }
case 1:
  throw trap_breakpoint(STATE.v, pc);
case 2:
  require_privilege(PRV_M);
  set_pc_and_serialize(p->get_state()->mepc->read());
  {
    reg_t s = STATE.mstatus->read();
    reg_t prev_prv = get_field(s, MSTATUS_MPP);
    reg_t prev_virt = get_field(s, MSTATUS_MPV);
    if (prev_prv != PRV_M) s = set_field(s, MSTATUS_MPRV, 0);
    s = set_field(s, MSTATUS_MIE, get_field(s, MSTATUS_MPIE));
    s = set_field(s, MSTATUS_MPIE, 1);
    s = set_field(s, MSTATUS_MPP, p->extension_enabled('U') ? PRV_U : PRV_M);
    s = set_field(s, MSTATUS_MPV, 0);
    s = set_field(s, MSTATUS_MPELP, elp_t::NO_LP_EXPECTED);
    s = set_field(s, MSTATUS_MDT, 0);
    STATE.mstatus->write(s);
    p->set_privilege(prev_prv, prev_virt);
  }
  break;
case 3:
  if (get_field(STATE.mstatus->read(), MSTATUS_TW)) {
    require_privilege(PRV_M);
  } else if (STATE.v) {
    if (STATE.prv == PRV_U || get_field(STATE.hstatus->read(), HSTATUS_VTW))
      require_novirt();
  } else if (p->extension_enabled('S')) {
    require_privilege(PRV_S);
  }
  STATE.in_wfi = !STATE.debug_mode && !p->get_cfg().wfi_as_nop;
  yield_hart();
  break;
case 4:
  break;
case 5:
  MMU.flush_icache();
  break;
default:
  throw trap_illegal_instruction(insn.bits());
}
