data {
  int m;
}
transformed data {
  int n = m+1;
  int a[n];
  for (i in 1:n-1) {
    a[i] = i;
  }
}