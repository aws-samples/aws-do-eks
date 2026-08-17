#!/bin/bash

# Split an aiperf profile_export.jsonl into its stalled tail and its steady state.
# See the header of aiperf-clean-tail.py for why a disagg run needs this before its
# TTFT mean and upper percentiles are reported.
#
# Usage: ./aiperf-clean-tail.sh <path-to-profile_export.jsonl> [ttft_cutoff_ms]
# The export is written to ${ARTIFACT_DIR} by test-aiperf.sh, which lives on the
# shared model volume; copy it out of any pod that mounts that volume, or run this
# from a machine that has it mounted.

source .env

export CMD="python3 ./aiperf-clean-tail.py ${1:-./profile_export.jsonl} ${2:-5000}"

if [ ! "$VERBOSE" == "false" ]; then echo -e "\n${CMD}\n"; fi

eval "${CMD}"
