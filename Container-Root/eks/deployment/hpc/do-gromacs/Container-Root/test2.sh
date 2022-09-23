#!/bin/sh

# Network latency test with sockets
# This test is only applicable when TO=kubernetes
if [ "$TO" == "kubernetes" ]; then

  # Generate manifest
  cat /app/manifests/test-osu-latency-sockets.yaml-template | envsubst > /app/manifests/test-osu-latency-sockets.yaml

  # Cleanup any previous tests
  kubectl delete -f /app/manifests/test-osu-latency-sockets.yaml

  # Run new test
  kubectl apply -f /app/manifests/test-osu-latency-sockets.yaml

  # Wait until mpi test job is completed or it times out
  TIMEOUT=100
  start_time=$(date +%s)
  status=$(kubectl get pods | grep test-osu-latency-sockets-launcher | awk -e '{print $3}')
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
      status=$(kubectl get pods | grep test-osu-latency-sockets-launcher | awk -e '{print $3}')
  done

  # Analyze log if job completed
  if [ "$status" == "Completed" ]; then
    kubectl logs $(kubectl get pods | grep test-osu-latency-sockets-launcher | cut -d ' ' -f 1) > /tmp/test-osu-latency-launcher-sockets.log
    verification=$(cat /tmp/test-osu-latency-launcher-sockets.log | grep "OSU MPI Latency Test" | wc -l)
    if [ "${verification}" == "1" ]; then
      TEST_RESULT="SUCCEEDED"
    else
      TEST_RESULT="FAILED"
    fi
    echo "Test log with standard networking:"
    cat /tmp/test-ous-latency-launcher-sockets.log
  fi

  # Display test result
  echo ""
  echo "Test2 $TEST_RESULT"

  # Cleanup
  kubectl delete -f /app/manifests/test-osu-latency-sockets.yaml

else
  echo ""
  echo "This test is only applicable for Kubernetes Target Orchestrator"
  echo "Skipping ..."
fi

