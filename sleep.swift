app (external o) sleep(int time) {
  sleep time;
}


/* Main program */
external rups[];

int t = 300;
int a[];

iterate ix {
  a[ix] = ix;
} until (ix == 1300);

foreach ai,i in a {
  rups[i] = sleep(t);
}
