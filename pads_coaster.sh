#!/bin/bash

#PBS -q short
#PBS -l walltime=02:00:00
#PBS -A CI-CCR000013

/home/aespinosa/swift/cogkit/modules/provider-coaster/resources/worker.pl \
    http://communicado.ci.uchicago.edu:60999 FOOblock /home/aespinosa/tmp 7202
