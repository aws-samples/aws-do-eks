#!/bin/sh

# Unit test of container

/opt/view/bin/gmx_mpi
if [ "$?" == "0" ]; then
	echo "Test1 succeeded"
else
	echo "Return code $?"
	echo "Test1 failed"
fi
