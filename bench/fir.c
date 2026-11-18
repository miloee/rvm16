int fir(const int *x, const int *h, int n) {
  int y = 0;
  for (int i = 0; i < n; i++)
    y += x[i] * h[i];
  return y;
}
