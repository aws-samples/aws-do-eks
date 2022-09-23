# do-gromacs - A Gromacs container built and manaed with the Do framwork
This project buils a container with an embedded [Gromacs](https://gromacs.org) moleucular dynamics pipeline which runs both locally or on Kubertnetes.

## Prerequisites
The following prerequisites are required to successfully run the Gromacs pipeline:
* AWS Account
* EKS cluster compliant with the [eks-hpc.yaml](https://github.com/aws-samples/aws-do-eks/blob/main/Container-Root/eks/eks-hpc.yaml) cluster manifest

## Configure
To select whether the container should run locally on Docker or on a Kubernetes cluster, opend the configuration file by executing ```./config.sh``` and set the target orchestrator through the ```TO``` setting.

## Build
Execute ```./build.sh``` to create the container image

## Push
Execute ```./push.sh``` to push the created container image to the Elastic Container Registry (ECR) in the current AWS account. This is necessary if you plan to run the container on Kubernetes.

## Test
Execute ```./test.sh``` to run unit tests against the container. When the Target Orchestrator is Kubernetes, the OSU benchmark tests will be executed with and without EFA enabled. The difference in network performance can be observed in the results.

## Run
Execute ```./run.sh``` to lanch the container on the configured Target Orchestrator.

## Exec
The ```./exec.sh``` script, opens a command shell in your running ```do-gromacs``` container.

## Launch Gromacs Pipeline
Execute ```./run-mpi.sh all``` to run the multi-step Gromacs pipeline inside the container or on your EKS cluster, depending on your configuration.

## Review results
Results are stored in the ```/data``` directory, accessible from inside the ```do-gromacs``` container. The result files can be shipped to a desktop station that runs [Visual Molecular Dynamics (VMD)](https://www.ks.uiuc.edu/Research/vmd/) for graphical interpretation.

## Stop
To shut-down the ```do-gromacs``` container, just execute the ```./stop.sh``` script.

