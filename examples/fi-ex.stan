functions {
  int incr(int x) {
    int y = 1;
    return x + y;
  }
}
transformed data {
  int a = 2;
  int b = incr(a);
}