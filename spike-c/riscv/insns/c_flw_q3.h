require_extension(EXT_ZC16);
require_extension('F');
require_fp;
static const reg_t bases[4] = {8, 9, 2, 3};
reg_t addr = READ_REG(bases[q3_fp_base]) + q3_fp_off * 4;
WRITE_FREG(q3_fp_fd, f32(MMU.load<uint32_t>(addr)));
