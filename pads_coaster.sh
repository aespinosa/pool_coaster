#!/bin/bash

#PBS -q short
#PBS -l walltime=04:00:00
#PBS -A CI-CCR000013
#PBS -m n

/home/aespinosa/swift/cogkit/modules/provider-coaster/resources/worker.pl \
    http://communicado.ci.uchicago.edu:60999 PADS /home/aespinosa/tmp 14402
