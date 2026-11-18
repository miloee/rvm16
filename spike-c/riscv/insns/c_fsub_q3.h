require_extension(EXT_ZC16);
require_extension('F');
require_fp;
softfloat_roundingMode = STATE.frm->read();
WRITE_FREG(q3_fp_fd, f32_sub(READ_FREG_F(q3_fp_fd), READ_FREG_F(q3_fp_fs2)));
set_fp_exceptions;
