#!/bin/bash
#
# Copyright (C) 2026 Ivan Cao-Berg and River Zhu
#
# Written by Ivan Cao-Berg and River Zhu.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License version 2 as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# SPDX-License-Identifier: GPL-2.0-only

# Submit one round of the stage 2 GPU benchmark: every example on every GPU
# type, one job each.
#
# Usage, from this directory:
#   ./submit.sh -r <repeat> [-n] [example ...]
#
#   -r  repeat number (1, 2, 3, ...); submit the next round only after the
#       previous one finishes, so runs don't share nodes with each other
#   -n  dry run: print the sbatch commands without submitting
#   example ...  directories to run (default: every example*/ here)
#
# Set GPUS to change the GPU types, e.g. GPUS="nvidia_rtx_a6000".
#
# A run is skipped if it already succeeded or is still queued or running, so
# the same round can be resubmitted to retry failed runs. Examples without
# stage 1 output (run stage1.sh in them first) are skipped too.

# Abort on any failed command (-e), unset variable (-u) or failure inside a
# pipeline (-o pipefail).
set -euo pipefail

# GPU types to benchmark, space-separated, as named in the gpu partition's
# GRES (sinfo -p gpu -o %G).
GPUS=${GPUS:-"nvidia_rtx_a6000 nvidia_geforce_rtx_2080_ti"}

# Defaults, overridden by the command-line flags parsed below.
repeat="5"
dry_run=false
while getopts "r:n" opt; do
  case $opt in
    r) repeat=$OPTARG ;;
    n) dry_run=true ;;
    *) exit 2 ;;
  esac
done
# Drop the parsed flags so "$@" holds only the example directories.
shift $((OPTIND - 1))

# The repeat must be a plain number.
if [[ ! "$repeat" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 -r <repeat> [-n] [example ...]" >&2
  exit 2
fi

# Work from the directory holding this script so example paths resolve
# relative to gpu-benchmarks/.
cd "$(dirname "$(realpath "$0")")"

# Examples named on the command line (trailing slashes stripped, so tab
# completion works), or else every example*/ directory in natural order
# (example2 before example10).
if (( $# > 0 )); then
  examples=("${@%/}")
else
  examples=($(ls -d example*/ | tr -d / | sort -V))
fi

# Names of this user's jobs that are pending or running, one per line, taken
# once up front. Tolerate squeue failing (e.g. on a node without Slurm) so a
# dry run still works.
queued=$(squeue -u "${USER:-$(whoami)}" -h -o %j 2>/dev/null || true)

# One job per (example, GPU) pair.
for example in "${examples[@]}"; do
  # Stage 2 needs the <name>_data.json that stage1.sh writes to output/<name>/.
  if ! compgen -G "$example/output/*/*_data.json" > /dev/null; then
    echo "skip $example: no stage 1 output; run stage1.sh there first"
    continue
  fi
  for gpu in $GPUS; do
    # Unique job name per example, GPU and repeat, e.g.
    # af3-s2-example3-nvidia_rtx_a6000-r2. It identifies the run in squeue and, through
    # the %x-%j.out output pattern in stage2.sh, names its log file.
    name=af3-s2-$example-$gpu-r$repeat

    # Don't double-submit a run that is still pending or running.
    if grep -qx "$name" <<< "$queued"; then
      echo "skip $name: queued or running"
      continue
    fi
    # A finished run leaves a <name>-<jobid>.out log containing a
    # "Done running" line; any such log means the run already succeeded.
    if grep -lqs "^Done running" "$example/$name"-*.out; then
      echo "skip $name: already done"
      continue
    fi

    # --gres overrides the GPU type in stage2.sh's #SBATCH lines. AF3_GPU and
    # AF3_REPEAT tell stage2.sh where to write its results
    # (output/stage2/<gpu>/r<repeat>/) and are echoed in the log for parsing.
    cmd=(sbatch --parsable --gres="gpu:$gpu:1" --job-name="$name"
         --export=ALL,AF3_GPU="$gpu",AF3_REPEAT="$repeat" stage2.sh)
    if $dry_run; then
      echo "(cd $example && ${cmd[*]})"
    else
      # Submit from inside the example directory so the job's
      # SLURM_SUBMIT_DIR (and with it the outputs and the log) is that
      # example. --parsable makes sbatch print just the job id.
      jobid=$(cd "$example" && "${cmd[@]}")
      echo "submitted $name: $jobid"
    fi
  done
done
