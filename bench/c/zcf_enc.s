.text
# Zcf encoding smoke test (RV32 F32 + Zcf)
c.flw  f8, 0(s0)
c.fsw  f8, 4(s0)
c.flwsp f8, 0(sp)
c.fswsp f8, 4(sp)
