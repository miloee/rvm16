require_extension(EXT_ZC16);
require_extension('F');
require_fp;
WRITE_FREG(q3_fp_fd, f32((uint32_t)READ_REG(q3_fp_fs2)));
