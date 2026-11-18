require_extension(EXT_ZC16);
require_extension('F');
require_fp;
softfloat_roundingMode = STATE.frm->read();
WRITE_FREG(q3_fp_fd, i32_to_f32((int32_t)READ_REG(q3_fp_fs2)));
set_fp_exceptions;
