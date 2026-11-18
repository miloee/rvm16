require_extension(EXT_ZC16);
require_extension('F');
require_fp;
WRITE_REG(q3_fp_fs2, sext32(READ_FREG(q3_fp_fd).v[0]));
