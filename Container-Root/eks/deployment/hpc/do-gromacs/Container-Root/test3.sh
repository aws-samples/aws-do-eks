#!/bin/sh

# Network latency test with EFA
# This test is only valud with Kubernetes
if [ "$TO" == "kubernetes" ]; then

  # Generate manifest
  cat /app/manifests/test-osu-latency-efa.yaml-template | envsubst > /app/manifests/test-osu-latency-efa.yaml

  # Cleanup any previous tests
  kubectl delete -f /app/manifests/test-osu-latency-efa.yaml

  # Run new test
  kubectl apply -f /app/manifests/test-osu-latency-efa.yaml

  # Wait until mpi test job is completed or it times out
  TIMEOUT=100
  start_time=$(date +%s)
  status=$(kubectl get pods | grep test-osu-latency-efa-launcher | awk -e '{print $3}')
  while [ ! "$status" == "Completed" ]; do
    now=$(date +%s)
    elapsed=$(( $now - $start_time ))
    if [ $elapsed -ge $TIMEOUT ]; then
      echo ""
      echo "$TIMEOUT seconds timeout reached waiting for test to complete"
      TEST_RESULT="FAILED"
      break
    fi
    echo "Waiting for test job to complete ( $elapsed seconds elapsed )  ..."
    sleep 5
    status=$(kubectl get pods | grep test-osu-latency-efa-launcher | awk -e '{print $3}')
  done

  # Analyze log if job completed
  if [ "$status" == "Completed" ]; then
    kubectl logs $(kubectl get pods | grep test-osu-latency-efa-launcher | cut -d ' ' -f 1) > /tmp/test-osu-latency-launcher-efa.log
    verification=$(cat /tmp/test-osu-latency-launcher-efa.log | grep "OSU MPI Latency Test" | wc -l)
    if [ "${verification}" == "1" ]; then
      TEST_RESULT="SUCCEEDED"
    else
      TEST_RESULT="FAILED"
    fi
    echo "Test log with EFA networking:"
    cat /tmp/test-ous-latency-launcher-efa.log
  fi

  # Display test result
  echo ""
  echo "Test3 $TEST_RESULT"

  # Cleanup
  kubectl delete -f /app/manifests/test-osu-latency-efa.yaml

else
  echo ""
  echo "Test3 is only applicable for Kubernetes Target Orchestrator"
  echo "Skipping ..."
  echo ""
fi

