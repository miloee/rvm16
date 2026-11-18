require_extension(EXT_ZC16);
require_extension('F');
require_fp;
WRITE_REG(q3_fp_fs2, f32_classify(READ_FREG_F(q3_fp_fd)));
