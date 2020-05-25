data {
  int n;
}
transformed data {
  int x = 0;
  for (i in 1:n) {
    x += i;
  }
}
