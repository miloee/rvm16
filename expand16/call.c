__attribute__((noinline)) int add(int a, int b) {
  return a + b;
}

int f(int a, int b) {
  return add(a, b) * 2;
}
