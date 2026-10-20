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
#
#SBATCH --job-name=af3-data
#SBATCH --partition=gpu
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=%x-%j.out

# Stage 1 of 2: build MSAs and find templates on the gpu partition, using its
# CPUs only (no GPU is requested). Stage 2 (stage2.sh) runs inference on a GPU.
#
# Usage, from this directory:
#   sbatch stage1.sh [input.json]
#
# The input defaults to fold_input.json in the directory you submit from. Run
# it once per example; ../submit.sh then benchmarks stage 2 from its output.
#
# gpu: three nodes with 40 or 64 cores and 192 or 256 GB of memory, a 12-hour
# maximum time limit and only 2 GB of memory by default, so the cores and
# memory are requested above. The four protein MSA searches run at the same
# time, so each gets 4 cores (--jackhmmer_n_cpu below).

# Print how long the script took when it exits, even on failure.
SECONDS=0
print_elapsed() {
  printf 'Elapsed time: %02d:%02d:%02d\n' \
    $((SECONDS / 3600)) $((SECONDS % 3600 / 60)) $((SECONDS % 60))
}
trap print_elapsed EXIT

# AlphaFold 3 container and genetic databases. There is no alphafold3 module on
# this cluster; set AF3_IMAGE or AF3_DATABASES to use other copies.
export AF3_IMAGE=${AF3_IMAGE:-$HOME/alphafold3/singularity-alphafold3-v3.0.4.sif}
export AF3_DATABASES=${AF3_DATABASES:-$HOME/alphafold3/databases}
if [[ ! -f "$AF3_IMAGE" ]]; then
  echo "AlphaFold 3 container not found: $AF3_IMAGE" >&2
  exit 1
fi

# Run run_alphafold.py in the container with the databases and scratch bound.
run_alphafold() {
  apptainer exec --bind "$AF3_DATABASES,$AF3_SCRATCH" \
    "$AF3_IMAGE" python /app/alphafold/run_alphafold.py "$@"
}

# Results go to output/ in the directory the job was submitted from (the
# example directory), where stage 2 reads the stage 1 output.
export AF3_OUTPUT_DIR=${AF3_OUTPUT_DIR:-$SLURM_SUBMIT_DIR/output}
mkdir -p "$AF3_OUTPUT_DIR"

# Slurm runs a copy of this script, so find files relative to the directory
# the job was submitted from.
export AF3_INPUT=$(realpath "${1:-$SLURM_SUBMIT_DIR/fold_input.json}")

# AlphaFold 3 names the output directory after the input's "name", with spaces
# replaced by underscores and characters other than [A-Za-z0-9_.-] removed.
export AF3_NAME=$(apptainer exec "$AF3_IMAGE" python3 -c '
import json, re, sys
name = json.load(open(sys.argv[1]))["name"].replace(" ", "_")
print(re.sub(r"[^A-Za-z0-9_.-]", "", name))
' "$AF3_INPUT")

data_json="$AF3_OUTPUT_DIR/$AF3_NAME/${AF3_NAME}_data.json"

echo "Input:  $AF3_INPUT"
echo "Output: $AF3_OUTPUT_DIR/$AF3_NAME"

# Skip the data pipeline if an earlier job already finished it.
if [[ -f "$data_json" ]]; then
  echo "Found $data_json; skipping the data pipeline."
else
  # Node-local scratch in /tmp, removed when the script exits. Set AF3_SCRATCH
  # to use (and keep) another directory.
  cleanup=:
  if [[ -z ${AF3_SCRATCH:-} ]]; then
    export AF3_SCRATCH=/tmp/$USER-af3-${SLURM_JOB_ID:-$$}
    cleanup='rm -rf "$AF3_SCRATCH"'
  fi
  mkdir -p "$AF3_SCRATCH/output" "$AF3_SCRATCH/tmp"

  # Copy results from scratch to $AF3_OUTPUT_DIR when the script exits, even on failure.
  trap 'rsync -a "$AF3_SCRATCH/output/" "$AF3_OUTPUT_DIR/"; '"$cleanup"'; print_elapsed' EXIT

  # Send temporary files from the MSA tools to scratch.
  export APPTAINERENV_TMPDIR="$AF3_SCRATCH/tmp"

  run_alphafold \
    --json_path="$AF3_INPUT" \
    --db_dir="$AF3_DATABASES" \
    --output_dir="$AF3_SCRATCH/output" \
    --jackhmmer_n_cpu=4 \
    --nhmmer_n_cpu=4 \
    --norun_inference
fi
