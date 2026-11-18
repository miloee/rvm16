require_extension(EXT_ZC16);
require_extension('F');
require_fp;
WRITE_FREG(q3_fp_fd, fsgnj32(freg(READ_FREG_F(q3_fp_fd)), freg(READ_FREG_F(q3_fp_fs2)), false, true));
