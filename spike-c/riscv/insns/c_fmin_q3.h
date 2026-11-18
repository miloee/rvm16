require_extension(EXT_ZC16);
require_extension('F');
require_fp;
float32_t fd = READ_FREG_F(q3_fp_fd);
float32_t fs2 = READ_FREG_F(q3_fp_fs2);
bool less = f32_lt_quiet(fd, fs2) || (f32_eq(fd, fs2) && (fd.v & F32_SIGN));
float32_t res;
if (isNaNF32UI(fd.v) && isNaNF32UI(fs2.v))
  res = f32(defaultNaNF32UI);
else
  res = (less || isNaNF32UI(fs2.v)) ? fd : fs2;
WRITE_FREG(q3_fp_fd, res);
