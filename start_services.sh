#!/bin/bash

NUMBER=$1
SERVICE='/home/aespinosa/swift/trunk/bin/coaster-service'
COASTER_PORT=62000
WORKER_PORT=61000

for i in `seq 0 $((NUMBER - 1))`; do
  $SERVICE -port $((COASTER_PORT + i)) -localport $((WORKER_PORT + i)) &
done

wait
