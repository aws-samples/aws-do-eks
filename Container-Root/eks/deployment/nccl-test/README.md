# NCCL Tests on EKS

Configurable NCCL tests on EKS.
These tests are designed to work on any of the [EFA-enabled](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types) GPU instance types.

## Deploy kubeflow mpi-operator

```bash
pushd ../kubeflow/mpi-operator
./deploy.sh
popd
```

## Build and push test container image

```bash
pushd cuda-efa-nccl-tests
./build.sh
./push.sh
```

## Configure NCCL test

```bash
./config.sh
```

Available settings:

* INSTANCE_TYPE - the targeted instance type where this test should run
* TOTAL_GPUS - the total number of GPUs across all nodes
* NUM_WORKERS - number of cluster nodes to run the test on
* GPU_PER_WORKER - number of GPUs per node
* EFA_PER WORKER - number of EFA adapters per node, can be 0
* FI_PROVIDER - network provider 'efa' or 'sockets'
* Other - NCCL, FI, MEMORY, and other settings that may be specific to the instance type

## Run test

```bash
./run.sh [test_name]
```

If `test_name` is not specified, then the `all-reduce` test is run.
Environment variable values from `.env` are replaced in all-reduce.yaml-template 
and saved as file `all-reduce.yaml`. Then `kubectl apply -f ./all-reduce.yaml` is executed.

If `test_name` is specified, then the same pattern is applied, using the test name instead of `all-reduce`.
Example: `./run.sh fi-info`

## See status

```bash
./status.sh
```

This command will list the mpi jobs and pods

## See logs

```bash
./logs.sh
```

This command will show the logs of the launcher pod

## Stop test

```bash
./stop.sh
```

This command will remove the mpijob

## Expected results

On `p5.48xlarge` single node:

```text
[1,3]<stdout>:test-nccl-efa-worker-0:23:75 [3] NCCL INFO Connected NVLS tree
[1,3]<stdout>:test-nccl-efa-worker-0:23:75 [3] NCCL INFO threadThresholds 8/8/64 | 64/8/64 | 512 | 512
[1,3]<stdout>:test-nccl-efa-worker-0:23:75 [3] NCCL INFO 24 coll channels, 16 nvls channels, 32 p2p channels, 32 p2p channels per peer
[1,0]<stdout>:#                                                              out-of-place                       in-place          
[1,0]<stdout>:#       size         count      type   redop    root     time   algbw   busbw #wrong     time   algbw   busbw #wrong
[1,0]<stdout>:#        (B)    (elements)                               (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)       
[1,0]<stdout>:  2147483648     536870912     float     sum      -1   8019.8  267.77  468.60      0   8019.5  267.78  468.62      0
[1,0]<stdout>:# Avg bus bandwidth    : 114.556 
```

On `p5.48xlarge` two nodes:

```text
[1,10]<stdout>:test-nccl-efa-worker-1:23:69 [2] NCCL INFO Connected NVLS tree
[1,10]<stdout>:test-nccl-efa-worker-1:23:69 [2] NCCL INFO threadThresholds 8/8/64 | 128/8/64 | 512 | 512
[1,10]<stdout>:test-nccl-efa-worker-1:23:69 [2] NCCL INFO 16 coll channels, 16 nvls channels, 16 p2p channels, 2 p2p channels per peer
[1,0]<stdout>:#                                                              out-of-place                       in-place          
[1,0]<stdout>:#       size         count      type   redop    root     time   algbw   busbw #wrong     time   algbw   busbw #wrong
[1,0]<stdout>:#        (B)    (elements)                               (us)  (GB/s)  (GB/s)            (us)  (GB/s)  (GB/s)
[1,0]<stdout>:  2147483648     536870912     float     sum      -1   9175.1  234.05  438.85      0   9166.2  234.28  439.28      0
[1,0]<stdout>:# Avg bus bandwidth    : 53.2202 
```

Other `P5.48xlarge`:

```text
16 nodes:
Avg bus bandwidth    : 21.1951

64 nodes:
Avg bus bandwidth    : 23.9904
```

