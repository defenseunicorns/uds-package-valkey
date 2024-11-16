#!/bin/bash

# List of job names to monitor
JOBS=("valkey-test-standalone" "valkey-test-replicated-w-sentinel")
NAMESPACE="valkey-test"


# Function to get the status of a job
get_job_status() {
  job_name=$1
  kubectl get job "$job_name" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null
}

# Function to check if a job is complete
is_job_complete() {
  job_name=$1
  kubectl get job "$job_name" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null
}

# Watch loop
while [ -n "$JOBS" ]; do
  UPDATED_JOBS=""

  for job in $JOBS; do
    # Check for failed condition
    if [ "$(get_job_status "$job")" = "True" ]; then
      echo "Error: Job '$job' failed."
      exit 1
    fi

    # Check if the job is complete
    if [ "$(is_job_complete "$job")" = "True" ]; then
      echo "Job '$job' completed successfully."
    else
      # Add unfinished jobs back to the updated list
      UPDATED_JOBS="$UPDATED_JOBS $job"
    fi
  done

  # Update the job list with unfinished jobs
  JOBS="$UPDATED_JOBS"

  # Wait before the next check
  sleep 5
done

echo "All jobs completed successfully."
exit 0