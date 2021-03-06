# Kubernetes Ops

This folder contains frequently used Kubernetes commands scripted for convenience and productivity.
Many of the scripts accept arguments. 
The script name is indicative of the arguments and the order in which they are expected.

Example:
```
./pod-exec-ns-cmd.sh <pod_unique_prefix> <namespace> <command>
```

When specifying a pod name it is not necessary to specify the entire name, it is sufficient to provide the beginning of the name as long as that makes the pod unique. 

Example:
```
./pods-list.sh

NAME                        READY   STATUS    RESTARTS   AGE
fsx-app                     1/1     Running   0          107m
simnet-mpi-launcher-22zkt   1/1     Running   0          6m59s
simnet-mpi-worker-0         1/1     Running   0          6m59s
simnet-mpi-worker-1         1/1     Running   0          6m59s

./pod-exec.sh fs
[root@fsx-app /]#
```
Another common naming pattern is the command variation indicated by the suffix. 
A -watch sufix indicates that the command will be executed periodically and monitored until interrupted with Ctl-C.
A -list suffix indicates that the command will be executed only one time.

Example:
```
./pods-list.sh
vs
./pods-watch.sh
```
