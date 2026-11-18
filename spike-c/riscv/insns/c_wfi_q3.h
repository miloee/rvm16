require_extension(EXT_ZC16);
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
