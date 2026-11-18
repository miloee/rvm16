#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>

volatile unsigned long long tohost;
volatile unsigned long long fromhost;
FILE *stdin;

extern char _heap_start[];
extern char _heap_end[];
static char *heap;

void *malloc(size_t n) {
  char *p;
  if (!heap) heap = _heap_start;
  n = (n + 7) & ~(size_t)7;
  if (heap + n > _heap_end) return 0;
  p = heap;
  heap += n;
  return p;
}
void free(void *p) { (void)p; }

char *fgets(char *b, int n, FILE *f) {
  static int call;
  (void)n; (void)f;
  if (call == 0) { call = 1; b[0] = '1'; b[1] = '0'; b[2] = (char)10; b[3] = 0; }
  else { b[0] = 'q'; b[1] = 0; }
  return b;
}

int atoi(const char *s) {
  int n = 0;
  while (*s >= '0' && *s <= '9') n = n * 10 + (*s++ - '0');
  return n;
}
static void pc(char c) {
  tohost = (1ULL << 56) | (1ULL << 48) | (unsigned char)c;
  while (tohost) ;
}
static void ps(const char *s) {
  if (!s) s = "(null)";
  while (*s) pc(*s++);
}
static void pu(unsigned long v, unsigned base) {
  char b[32]; int i = 0;
  if (!v) { pc('0'); return; }
  while (v) { unsigned d = v % base; b[i++] = (char)(d < 10 ? '0' + d : 'a' + d - 10); v /= base; }
  while (i--) pc(b[i]);
}
static void pd(long v) {
  if (v < 0) { pc('-'); pu((unsigned long)(-v), 10); }
  else pu((unsigned long)v, 10);
}
unsigned int __fixunsdfsi(double);
static void pf(double v) {
  unsigned long i;
  if (v < 0) { pc('-'); v = -v; }
  i = __fixunsdfsi(v);
  pd((long)i);
  ps(".00");
}
int vprintf(const char *fmt, va_list ap) {
  for (; *fmt; fmt++) {
    if (*fmt != '%') { pc(*fmt); continue; }
    fmt++;
    while (*fmt == '0' || *fmt == '-' || *fmt == '+' || *fmt == ' ' || *fmt == '#' ||
           (*fmt >= '1' && *fmt <= '9') || *fmt == '.' || *fmt == 'l' || *fmt == 'h') {
      if (*fmt == 'l') { fmt++; break; }
      fmt++;
    }
    switch (*fmt) {
      case 'd': pd(va_arg(ap, int)); break;
      case 'u': pu(va_arg(ap, unsigned), 10); break;
      case 'x': pu(va_arg(ap, unsigned), 16); break;
      case 's': ps(va_arg(ap, const char *)); break;
      case 'c': pc((char)va_arg(ap, int)); break;
      case 'f': pf(va_arg(ap, double)); break;
      case '%': pc('%'); break;
      default: pc('%'); if (*fmt) pc(*fmt); break;
    }
  }
  return 0;
}
int printf(const char *f, ...) {
  va_list ap; int r;
  va_start(ap, f); r = vprintf(f, ap); va_end(ap);
  return r;
}
static unsigned long clk;
int clock(void) { clk += 1000000; return (int)clk; }


float sqrtf(float x) { return __builtin_sqrtf(x); }
float fabsf(float x) { return __builtin_fabsf(x); }

void exit(int code) {
  tohost = ((unsigned long long)code << 1) | 1;
  for (;;) ;
}
