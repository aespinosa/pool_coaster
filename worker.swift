app (external o) worker(int time) {
  worker time;
}

/* Main program */
external rups[];

int t = 7200;
int a[];

iterate ix {
  a[ix] = ix;
} until (ix == 1300);

foreach ai,i in a {
  rups[i] = worker(t);
}
