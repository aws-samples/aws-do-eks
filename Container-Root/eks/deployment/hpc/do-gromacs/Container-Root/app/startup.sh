#!/bin/sh

# Container startup script
echo "Container-Root/startup.sh executed"

bash -c "/app/run-mpi.sh all"

