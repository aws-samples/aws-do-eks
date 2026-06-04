#!/bin/bash

# List nodes with their available and allocated resources

DESCRIBE=$(kubectl describe nodes)

FMT="%-55s %-20s %8s %8s %10s %10s %6s %6s %6s %6s"
printf "$FMT
" "NODE" "INSTANCE-TYPE" "A-CPU" "U-CPU" "A-MEM" "U-MEM" "A-EFA" "U-EFA" "A-GPU" "U-GPU"
printf "$FMT
" "----" "-------------" "-----" "-----" "-----" "-----" "-----" "-----" "-----" "-----"

echo "$DESCRIBE" | awk -v fmt="$FMT" '
function to_mi(val) {
  if (val ~ /Ki$/) { sub(/Ki$/,"",val); return int(val/1024) "Mi" }
  if (val ~ /Mi$/) { return val }
  if (val ~ /Gi$/) { sub(/Gi$/,"",val); return int(val*1024) "Mi" }
  if (val ~ /Ti$/) { sub(/Ti$/,"",val); return int(val*1024*1024) "Mi" }
  if (val ~ /[0-9]$/) { return int(val/1048576) "Mi" }
  return val
}
/^Name:/ { name=$2 }
/instance-type/ {
  idx=index($0,"instance-type=")
  if(idx>0){ rest=substr($0,idx+14); sub(/[, ].*/,"",rest); itype=rest }
}
/^Allocatable:/ { in_alloc=1; next }
in_alloc && /cpu:/ { a_cpu=$2; next }
in_alloc && /memory:/ { a_mem=$2; next }
in_alloc && /nvidia.com\/gpu:/ { a_gpu=$2; next }
in_alloc && /vpc.amazonaws.com\/efa:/ { a_efa=$2; next }
in_alloc && /^[^ ]/ { in_alloc=0 }
/Allocated resources:/ { in_used=1; next }
in_used && /nvidia.com\/gpu/ { u_gpu=$2; next }
in_used && /vpc.amazonaws.com\/efa/ { u_efa=$2; next }
in_used && /memory/ && !/nvidia/ && !/vpc/ { u_mem=$2; next }
in_used && /cpu/ && !/nvidia/ && !/vpc/ { u_cpu=$2; next }
(in_used && /^[^ ]/) || /^Events:/ {
  if (in_used && name != "") {
    if(a_gpu=="") a_gpu="0"
    if(a_efa=="") a_efa="0"
    if(a_mem=="") a_mem="0"
    if(u_gpu=="") u_gpu="0"
    if(u_efa=="") u_efa="0"
    if(u_mem=="") u_mem="0"
    printf fmt, name, itype, a_cpu, u_cpu, to_mi(a_mem), to_mi(u_mem), a_efa, u_efa, a_gpu, u_gpu
    print ""
  }
  a_gpu=""; a_efa=""; u_gpu=""; u_efa=""; a_mem=""; u_mem=""; in_used=0
}
END {
  if(in_used && name!="") {
    if(a_gpu=="") a_gpu="0"
    if(a_efa=="") a_efa="0"
    if(a_mem=="") a_mem="0"
    if(u_gpu=="") u_gpu="0"
    if(u_efa=="") u_efa="0"
    if(u_mem=="") u_mem="0"
    printf fmt, name, itype, a_cpu, u_cpu, to_mi(a_mem), to_mi(u_mem), a_efa, u_efa, a_gpu, u_gpu
    print ""
  }
}'
