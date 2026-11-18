require_extension(EXT_ZC16);
require_extension('F');
require_fp;
softfloat_roundingMode = STATE.frm->read();
WRITE_REG(q3_fp_fs2, sext32(f32_to_i32(READ_FREG_F(q3_fp_fd), STATE.frm->read(), true)));
set_fp_exceptions;
