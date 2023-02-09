#!/bin/bash

# This sample, non-production-ready script to launch a sample gromacs (https://gromacs.org) job on AWS Batch.
# It runs the "Lysozyme in Water" tutorial which can be found here: http://www.mdtutorials.com/gmx/lysozyme/index.html
#
# © 2022 Amazon Web Services, Inc. or its affiliates. All Rights Reserved.  
# This AWS Content is provided subject to the terms of the AWS Customer Agreement available at  
# http://aws.amazon.com/agreement or other written agreement between Customer and either
# Amazon Web Services, Inc. or Amazon Web Services EMEA SARL or both.
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

set -o errexit
set -o pipefail

function usage() {
    cat <<EOF

Usage: $0 <step>
Steps:
  prepare_data
  energy_min
  eq_phase1
  eq_phase2
  prod_md
  post_analysis
  all

Run parameters are set through environment variables, see top of script.

EOF
}

# load spack env
# shellcheck source=/dev/null
source /etc/profile.d/z10_spack_environment.sh
GMX=$(command -v gmx_mpi)
MPIRUN=$(command -v mpirun)

# gromacs inputs
I_PDB=${I_PDB:="/inputs/1aki.pdb"}
I_IONS=${I_IONS:="/inputs/ions.mdp"}
I_MD=${I_MD:="/inputs/md.mdp"}
I_MINIM=${I_MINIM:="/inputs/minim.mdp"}
I_NPT=${I_NPT:="/inputs/npt.mdp"}
I_NVT=${I_NVT:="/inputs/nvt.mdp"}

export DATA_DIR=${DATA_DIR:="/data"}
echo "DATA_DIR=$DATA_DIR"
MDRUN_ARGS=${MDRUN_ARGS:=""}

# process placement
NPROC=$(nproc)
THREADS_PER_CORE=${THREADS_PER_CORE:=2}
CORES=${CORES:=$((NPROC/THREADS_PER_CORE))}
RANKSPN=${RANKSPN:=$CORES}
OMP_NUM_THREADS=${OMP_NUM_THREADS:=$((CORES/RANKSPN))}
BINDTO=${BINDTO:="core"}

# debug flags
FI_LOG_LEVEL=${FI_LOG_LEVEL:="warn"}
OMPI_MCA_verbose=${OMPI_MCA_verbose:=0}

# don't fail because we're not actually under batch
AWS_BATCH_JOB_NUM_NODES=${AWS_BATCH_JOB_NUM_NODES:=1}

export PATH LD_LIBRARY_PATH OMP_NUM_THREADS FI_LOG_LEVEL OMPI_MCA_verbose
export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1

#MPI_OPTS=(-hostfile /hostfile-ompi)
MPI_OPTS=()
MPI_OPTS+=(-np $((AWS_BATCH_JOB_NUM_NODES*RANKSPN)))
MPI_OPTS+=(-npernode "$RANKSPN")
MPI_OPTS+=(--bind-to "$BINDTO")
MPI_OPTS+=(-x PATH)
MPI_OPTS+=(-x LD_LIBRARY_PATH)
MPI_OPTS+=(-x FI_LOG_LEVEL)
MPI_OPTS+=(-x OMPI_MCA_verbose)
MPI_OPTS+=(-x OMP_NUM_THREADS)

# hack to make sure openmpi doesn't complain if this isn't exported
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH

# helper functions
# complete_or_timeout - wait the specified pod to enter status Completed
# time out if waiting longer than the specified number of seconds
# The function requires two parameters
#    pod_name_prefix - a string that uniquely identifies the job pod name
#    timeout in seconds to not exceed while waiting for the pod to enter Completed state
function complete_or_timeout() {
  set +o errexit
  set +o pipefail
  pod_name_prefix=$1
  timeout_seconds=$2
  echo "Waiting for job $1 to complete up to $2 seconds ..."
  start_time=$(date +%s)
  status=$(kubectl get pods | grep $pod_name_prefix | awk -e '{print $3}')
  echo "Current status: $status"
  while [ "$status" != "Completed" ]; do
    now=$(date +%s)
    elapsed=$(( $now - $start_time ))
    if [ $elapsed -ge $timeout_seconds ]; then
      echo ""
      echo "$timeout_seconds seconds timeout reached waiting for $pod_name_prefix to complete"
      export JOB_RESULT="FAILED"
      break
    fi
    echo "Waiting $pod_name_prefix to complete ( $elapsed seconds elapsed )  ..."
    sleep 5
    status=$(kubectl get pods | grep $pod_name_prefix | awk -e '{print $3}')
    echo "Current status: $status"
  done
  export JOB_RESULT="SUCCEEDED"
  set -o errexit
  set -o pipefail
}

# steps

# 1. prepare data
# inputs: I_PDB, I_IONS
# outputs: solv_ions.gro, topol.top
function prepare_data() {
  echo "Removing water molecules from PDB"
  grep -v HOH "$I_PDB" > clean.pdb
  echo "Generating topology"
  $GMX pdb2gmx -f clean.pdb -o processed.gro -water spce -ff oplsaa
  echo "Defining the box"
  $GMX editconf -f processed.gro -o newbox.gro -c -d 1.0 -bt cubic
  echo "Filling box with solvent"
  $GMX solvate -cp newbox.gro -cs spc216.gro -o solv.gro -p topol.top
  echo "Adding ions"
  $GMX grompp -f "$I_IONS" -c solv.gro -p topol.top -o ions.tpr
  echo 13 | $GMX genion -s ions.tpr -o solv_ions.gro -p topol.top -pname NA -nname CL -neutral
}
# 2. Energy minimization
# inputs: solv_ions.gro, topol.top
# outputs: em.gro, em.edr, potential.xvg
function energy_min() {
  echo "Energy minimization"
  $GMX grompp -f "$I_MINIM" -c ${DATA_DIR}/solv_ions.gro -p ${DATA_DIR}/topol.top -o ${DATA_DIR}/em.tpr
  if [ "$TO" == "kubernetes" ]; then
    cat /app/manifests/mpi-energy-min.yaml-template | envsubst > /app/manifests/mpi-energy-min.yaml
    kubectl delete mpijob --all
    kubectl apply -f /app/manifests/mpi-energy-min.yaml
    complete_or_timeout mpi-energy-min-launcher 100
    if [ "$JOB_RESULT" == "FAILED" ]; then
      echo "Energy minimization failed. Terminating workflow ..."
      exit 1
    fi
  else
    $MPIRUN "${MPI_OPTS[@]}" "$GMX" mdrun $MDRUN_ARGS -ntomp "$OMP_NUM_THREADS" -v -deffnm em
  fi
  echo 10 0 | $GMX energy -f ${DATA_DIR}/em.edr -o ${DATA_DIR}/potential.xvg
}
# 3. Eq. phase 1
# inputs: I_NVT, em.gro, topol.top
# outputs: nvt.gro, nvt.edr, temperature.xvg
function eq_phase1() {
  echo "Performing equilibration: Phase 1"
  $GMX grompp -f "$I_NVT" -c ${DATA_DIR}/em.gro -r ${DATA_DIR}/em.gro -p ${DATA_DIR}/topol.top -o ${DATA_DIR}/nvt.tpr
  if [ "$TO" == "kubernetes" ]; then
    cat /app/manifests/mpi-eq-phase1.yaml-template | envsubst > /app/manifests/mpi-eq-phase1.yaml
    kubectl delete mpijob --all
    kubectl apply -f /app/manifests/mpi-eq-phase1.yaml
    complete_or_timeout mpi-eq-phase1-launcher 800
    if [ "$JOB_RESULT" == "FAILED" ]; then
      echo "Equilibration Phase 1 failed. Terminating workflow ..."
      exit 1
    fi
  else
    $MPIRUN "${MPI_OPTS[@]}" "$GMX" mdrun $MDRUN_ARGS -ntomp "$OMP_NUM_THREADS" -deffnm nvt
  fi
  echo 16 0 | $GMX energy -f ${DATA_DIR}/nvt.edr -o ${DATA_DIR}/temperature.xvg
}
# 4. Eq. phase 2
# inputs: I_NPT, nvt.gro, topol.top
# outputs: npt.gro, npt.edr, npt.cpt, pessure.xvg, density.xvg
function eq_phase2() {
  echo "Performing equilibration: Phase 2"
  $GMX grompp -f "$I_NPT" -c ${DATA_DIR}/nvt.gro -r ${DATA_DIR}/nvt.gro -t ${DATA_DIR}/nvt.cpt -p ${DATA_DIR}/topol.top -o ${DATA_DIR}/npt.tpr
if [ "$TO" == "kubernetes" ]; then
    cat /app/manifests/mpi-eq-phase2.yaml-template | envsubst > /app/manifests/mpi-eq-phase2.yaml
    kubectl delete mpijob --all
    kubectl apply -f /app/manifests/mpi-eq-phase2.yaml
    complete_or_timeout mpi-eq-phase2-launcher 800
    if [ "$JOB_RESULT" == "FAILED" ]; then
      echo "Equilibration Phase 2 failed. Terminating workflow ..."
      exit 1
    fi
  else
    $MPIRUN "${MPI_OPTS[@]}" "$GMX" mdrun $MDRUN_ARGS -ntomp "$OMP_NUM_THREADS" -deffnm ${DATA_DIR}/npt -s ${DATA_DIR}/npt.tpr
  fi
  echo 18 0 | $GMX energy -f ${DATA_DIR}/npt.edr -o ${DATA_DIR}/pressure.xvg
  echo 24 0 | $GMX energy -f ${DATA_DIR}/npt.edr -o ${DATA_DIR}/density.xvg
}
# 5. production MD
# inputs: I_MD, npt.gro, npt.cpt, topol.top
# outputs: md_0_1.*
function prod_md() {
  echo "Running production MD"
  $GMX grompp -f "$I_MD" -c ${DATA_DIR}/npt.gro -t ${DATA_DIR}/npt.cpt -p ${DATA_DIR}/topol.top -o ${DATA_DIR}/md_0_1.tpr
if [ "$TO" == "kubernetes" ]; then
    cat /app/manifests/mpi-prod-md.yaml-template | envsubst > /app/manifests/mpi-prod-md.yaml
    kubectl delete mpijob --all
    kubectl apply -f /app/manifests/mpi-prod-md.yaml
    complete_or_timeout mpi-prod-md-launcher 10000
    if [ "$JOB_RESULT" == "FAILED" ]; then
      echo "Production MD failed. Terminating workflow ..."
      exit 1
    fi
  else
    $MPIRUN "${MPI_OPTS[@]}" "$GMX" mdrun $MDRUN_ARGS -ntomp "$OMP_NUM_THREADS" -deffnm ${DATA_DIR}/md_0_1
  fi
  # if we had GPUs
  # $MPIRUN $MPI_OPTS $GMX mdrun -deffnm md_0_1 -nb gpu
}
# 6. post analysis
# inputs: md_0_1.*, em.*
# outputs: rmsd.xvg, rmsd_xtal.xvg, gyrate.xvg
function post_analysis() {
  echo "Running post-analysis"
  echo 1 0 | $GMX trjconv -s ${DATA_DIR}/md_0_1.tpr -f ${DATA_DIR}/md_0_1.xtc -o ${DATA_DIR}/md_0_1_noPBC.xtc -pbc mol -center
  echo 4 4 | $GMX rms -s ${DATA_DIR}/md_0_1.tpr -f ${DATA_DIR}/md_0_1_noPBC.xtc -o ${DATA_DIR}/rmsd.xvg -tu ns
  echo 4 4 | $GMX rms -s ${DATA_DIR}/em.tpr -f ${DATA_DIR}/md_0_1_noPBC.xtc -o ${DATA_DIR}/rmsd_xtal.xvg -tu ns
  echo 1 | $GMX gyrate -s ${DATA_DIR}/md_0_1.tpr -f ${DATA_DIR}/md_0_1_noPBC.xtc -o ${DATA_DIR}/gyrate.xvg
}

###
# Entrypoint
###

if [ $# -ne 1 ]; then
  usage
  exit 1
fi

# We prepare data in DATA_DIR
echo "Using data directory: $DATA_DIR"
[ ! -d "$DATA_DIR" ] && mkdir -p "$DATA_DIR"
if [ -n "$DATA_S3URI" ]; then
  echo "Synchronizing data from s3 bucket: $DATA_S3URI"
  aws s3 sync "$DATA_S3URI" "$DATA_DIR"
fi
cd "$DATA_DIR" || echo "failed to enter data dir"

echo "Using inputs: PDB($I_PDB), IONS($I_IONS), MD($I_MD), MINIM($I_MINIM), NPT($I_NPT), NVT($I_NVT)"
echo "Using process binding: CORES($CORES) RANKSPN($RANKSPN) OMP_NUM_THREADS($OMP_NUM_THREADS)"

case $1 in
  "prepare_data" | "energy_min" | "eq_phase1" | "eq_phase2" | "prod_md" | "post_analysis" )
    $1
    ;;
  "all")
    prepare_data
    energy_min
    eq_phase1
    eq_phase2
    prod_md
    post_analysis
    ;;
  *)
    usage
    exit 1
    ;;
esac

if [ -n "$DATA_S3URI" ]; then
  echo "Synchronizing data to s3 bucket: $DATA_S3URI"
  aws s3 sync "$DATA_DIR" "$DATA_S3URI"
fi

echo "Done."

