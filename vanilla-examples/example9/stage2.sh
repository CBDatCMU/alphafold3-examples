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
#SBATCH --job-name=af3-inference
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_rtx_a6000:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=02:00:00
#SBATCH --array=1-5
#SBATCH --output=%x-%A_%a.out

# Stage 2 of 2: predict the structure from the stage 1 output on one GPU.
#
# stage1.sh submits this script itself, depending on the stage 1 job. To run
# it on its own, from this directory, after stage1.sh finishes:
#   sbatch stage2.sh [input.json]
#
# Pass the same input as stage 1. It defaults to fold_input.json in the
# directory you submit from.
#
# Like stage 1, this is a job array with 5 tasks: task N predicts from
# output/replicate-N/ and writes its results there. Use the same --array as
# stage 1.
#
# gpu: two nodes with 2 NVIDIA RTX A6000 (48 GB) each, and one node with an
# NVIDIA GeForce RTX 2080 Ti (11 GB); 12-hour maximum time limit and only 2 GB
# of memory by default. The A6000 requested above fits every example. To use
# the 2080 Ti, which fits only small inputs, submit with
# --gres=gpu:nvidia_geforce_rtx_2080_ti:1.

set -euo pipefail

# AlphaFold 3 container and model weights. There is no alphafold3 module on
# this cluster; set AF3_IMAGE or AF3_WEIGHTS to use other copies.
export AF3_IMAGE=${AF3_IMAGE:-$HOME/alphafold3/singularity-alphafold3-v3.0.4.sif}
export AF3_WEIGHTS=${AF3_WEIGHTS:-$HOME/alphafold3/weights}
if [[ ! -f "$AF3_IMAGE" ]]; then
  echo "AlphaFold 3 container not found: $AF3_IMAGE" >&2
  exit 1
fi

# Run run_alphafold.py in the container on the GPU, with the weights and
# scratch bound.
run_alphafold() {
  apptainer exec --nv --bind "$AF3_WEIGHTS,$AF3_SCRATCH" \
    "$AF3_IMAGE" python /app/alphafold/run_alphafold.py "$@"
}

# Print how long the script took when it exits, even on failure.
SECONDS=0
print_elapsed() {
  printf 'Elapsed time: %02d:%02d:%02d\n' \
    $((SECONDS / 3600)) $((SECONDS % 3600 / 60)) $((SECONDS % 60))
}
trap print_elapsed EXIT

# Results go to output/replicate-N/ in the directory the job was submitted
# from (the example directory), where stage 2 reads the stage 1 output. N is
# the array task ID (1 when the script isn't run as an array). If you set
# AF3_OUTPUT_DIR, replicate-N/ is created inside it.
export AF3_REPLICATE=${SLURM_ARRAY_TASK_ID:-1}
export AF3_OUTPUT_DIR=${AF3_OUTPUT_DIR:-$SLURM_SUBMIT_DIR/output}/replicate-$AF3_REPLICATE
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

export AF3_DATA_JSON=${AF3_DATA_JSON:-$AF3_OUTPUT_DIR/$AF3_NAME/${AF3_NAME}_data.json}

if [[ ! -f "$AF3_DATA_JSON" ]]; then
  echo "Missing $AF3_DATA_JSON. Run stage1.sh first." >&2
  exit 1
fi

# Node-local scratch and JAX cache in /tmp, removed when the script exits. Set
# AF3_SCRATCH to use (and keep) another directory.
cleanup=:
if [[ -z ${AF3_SCRATCH:-} ]]; then
  export AF3_SCRATCH=/tmp/$USER-af3-${SLURM_JOB_ID:-$$}
  cleanup='rm -rf "$AF3_SCRATCH"'
fi
export AF3_JAX_CACHE_DIR=${AF3_JAX_CACHE_DIR:-$AF3_SCRATCH/jax_cache}
mkdir -p "$AF3_SCRATCH/output" "$AF3_SCRATCH/tmp" "$AF3_JAX_CACHE_DIR"

# Copy results from scratch to $AF3_OUTPUT_DIR when the script exits, even on failure.
trap 'rsync -a "$AF3_SCRATCH/output/" "$AF3_OUTPUT_DIR/"; '"$cleanup"'; print_elapsed' EXIT

export APPTAINERENV_TMPDIR="$AF3_SCRATCH/tmp"

# GPUs below compute capability 8.0, such as the RTX 2080 Ti, can't run the
# default Triton flash attention. Use the XLA one there, and turn off the XLA
# pass that upstream says gives wrong results on these GPUs.
flash_attention=triton
compute_cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n 1)
if (( ${compute_cap%%.*} < 8 )); then
  flash_attention=xla
  export APPTAINERENV_XLA_FLAGS="--xla_disable_hlo_passes=custom-kernel-fusion-rewriter"
fi
echo "GPU compute capability: $compute_cap; flash attention: $flash_attention"

run_alphafold \
  --json_path="$AF3_DATA_JSON" \
  --model_dir="$AF3_WEIGHTS" \
  --output_dir="$AF3_SCRATCH/output" \
  --jax_compilation_cache_dir="$AF3_JAX_CACHE_DIR" \
  --flash_attention_implementation="$flash_attention" \
  --norun_data_pipeline
