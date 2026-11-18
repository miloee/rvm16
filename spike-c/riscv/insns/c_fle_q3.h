require_extension(EXT_ZC16);
require_extension('F');
require_fp;
WRITE_REG(31, f32_le(READ_FREG_F(q3_fp_fd), READ_FREG_F(q3_fp_fs2)));
set_fp_exceptions;
