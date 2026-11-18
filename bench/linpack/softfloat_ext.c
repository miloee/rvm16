typedef unsigned int u32;

double __extendsfdf2(float x) {
  union { float f; u32 u; } in;
  u32 u, s, e, m, de;
  union { double d; struct { u32 lo, hi; } w; } out;
  in.f = x;
  u = in.u;
  s = (u >> 31) & 1;
  e = (u >> 23) & 0xFF;
  m = u & 0x7FFFFF;
  if (e == 0) {
    if (m == 0) de = 0;
    else {
      de = 1;
      while (!(m & 0x800000)) { m <<= 1; de--; }
      m &= 0x7FFFFF;
      de = 896 + de;
    }
  } else if (e == 255) de = 0x7FF;
  else de = e + 896;
  out.w.hi = (s << 31) | (de << 20) | (m >> 3);
  out.w.lo = m << 29;
  return out.d;
}

float __truncdfsf2(double x) { (void)x; return 0.0f; }
double __floatsidf(int x) { (void)x; return 0.0; }
double __floatunsidf(unsigned int x) { (void)x; return 0.0; }
double __adddf3(double a, double b) { (void)a; (void)b; return 0.0; }
double __subdf3(double a, double b) { (void)a; (void)b; return 0.0; }
double __muldf3(double a, double b) { (void)a; (void)b; return 0.0; }
double __divdf3(double a, double b) { (void)a; (void)b; return 0.0; }
int __ltdf2(double a, double b) { (void)a; (void)b; return 0; }
int __gtdf2(double a, double b) { (void)a; (void)b; return 0; }
int __ledf2(double a, double b) { (void)a; (void)b; return 0; }
int __gedf2(double a, double b) { (void)a; (void)b; return 0; }
int __eqdf2(double a, double b) { (void)a; (void)b; return 0; }
int __nedf2(double a, double b) { (void)a; (void)b; return 0; }
int __fixdfsi(double x) {
  union { double d; struct { u32 lo, hi; } w; } in;
  u32 e, m, r;
  int sign;
  in.d = x;
  sign = (in.w.hi >> 31) & 1;
  e = (in.w.hi >> 20) & 0x7FF;
  if (e < 1023) return 0;
  e -= 1023;
  if (e > 20) return sign ? (int)0x80000000 : 0x7FFFFFFF;
  m = (in.w.hi & 0xFFFFF) | 0x100000;
  r = m >> (20 - e);
  return sign ? -(int)r : (int)r;
}
unsigned int __fixunsdfsi(double x) {
  union { double d; struct { u32 lo, hi; } w; } in;
  u32 e, m, r;
  in.d = x;
  e = (in.w.hi >> 20) & 0x7FF;
  if (e < 1023) return 0;
  e -= 1023;
  if (e > 20) return 0xFFFFFFFF;
  m = (in.w.hi & 0xFFFFF) | 0x100000;
  r = m >> (20 - e);
  return r;
}
