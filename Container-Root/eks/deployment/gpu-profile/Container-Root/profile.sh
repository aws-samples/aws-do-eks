#!/bin/sh

# Container profile script
echo "Container-Root/profile.sh executed"

nsys profile --nic-metrics=true -w true -t cuda,nvtx,osrt,cudnn,cublas,mpi --mpi-impl=openmpi -s system-wide --capture-range=none --cudabacktrace=all --cuda-flush-interval=1000 -x true -o /wd/nsys-report-%h-%p.nsys-rep --stats=true /train.sh

