#!/bin/sh
# Copyright 2024 Defense Unicorns
# SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-Defense-Unicorns-Commercial

# List of job names to monitor (space-separated for POSIX compatibility)
JOBS="valkey-test-standalone valkey-test-replicated-w-sentinel"
NAMESPACE="valkey-test"

# Function to get the status of a job
get_job_status() {
  job_name=$1
  kubectl get job "${job_name}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}'
}

# Function to check if a job is complete
is_job_complete() {
  job_name=$1
  kubectl get job "${job_name}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}'
}

# Watch loop
while [ -n "${JOBS}" ]; do
  sleep 5
  UPDATED_JOBS=""

  for job in ${JOBS}; do
    # Check for failed condition
    ret="$(get_job_status "${job}")"
    if [ "${ret}" = "True" ]; then
      echo "Error: Job '${job}' failed."
      exit 1
    fi

    # Check if the job is complete
    ret="$(is_job_complete "${job}")"
    if [ "${ret}" = "True" ]; then
      echo "Job '${job}' completed successfully."
    else
      # Add unfinished jobs back to the updated list
      UPDATED_JOBS="${UPDATED_JOBS} ${job}"
    fi
  done

  # Update the job list with unfinished jobs
  JOBS="${UPDATED_JOBS}"
done

echo "All jobs completed successfully."
exit 0
