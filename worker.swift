app (external o) worker(int time) {
  worker "http://128.135.125.17:50007" "PRELIM" "/tmp";
}

/* Main program */
external rups[];

int t = 7200;
int a[];

iterate ix {
  a[ix] = ix;
} until (ix == 100);

foreach ai,i in a {
  rups[i] = worker(t);
}
