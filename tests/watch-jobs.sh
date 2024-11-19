#!/bin/bash
# Copyright 2024 Defense Unicorns
# SPDX-License-Identifier: AGPL-3.0-or-later OR LicenseRef-Defense-Unicorns-Commercial

# List of job names to monitor (space-separated string)
JOBS="valkey-test-standalone valkey-test-replicated-w-sentinel"
NAMESPACE="valkey-test"

# Function to get the status of a job
get_job_status() {
  local job_name="$1"
  kubectl get job "${job_name}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null
}

# Function to check if a job is complete
is_job_complete() {
  local job_name="$1"
  kubectl get job "${job_name}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null
}

# Monitoring loop
while [ -n "${JOBS}" ]; do
  UNFINISHED_JOBS=""

  for job in ${JOBS}; do
    # Check for failed condition
    job_status="$(get_job_status "${job}")"
    if [ "${job_status}" = "True" ]; then
      echo "Error: Job '${job}' failed."
      kubectl describe -n "${NAMESPACE}" jobs.batch "${job}"
      kubectl describe namespace "${NAMESPACE}"
      kubectl logs -n "${NAMESPACE}" jobs/"${job}"
      exit 1
    fi

    # Check if the job is complete
    job_complete="$(is_job_complete "${job}")"
    if [ "${job_complete}" = "True" ]; then
      echo "Job '${job}' completed successfully."
    else
      # Add unfinished job back to the list
      UNFINISHED_JOBS="${UNFINISHED_JOBS} ${job}"
    fi
  done

  # Update the JOBS variable with unfinished jobs
  JOBS="${UNFINISHED_JOBS}"

  # Break the loop if all jobs are completed
  if [ -z "${JOBS}" ]; then
    echo "All jobs completed successfully."
    break
  fi

  # Wait before the next check
  sleep 5
done
