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
#SBATCH --job-name=af3-stage2
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_rtx_a6000:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=01:00:00
#SBATCH --output=%x-%j.out

# Stage 2 of 2, GPU benchmark version: predict the structure from the stage 1
# output on one GPU and log the timings for ../collect_results.py.
#
# Usually submitted by ../submit.sh, which sets the GPU type, job name and
# repeat number. To submit one run by hand, from this directory:
#   AF3_GPU=nvidia_rtx_a6000 AF3_REPEAT=1 sbatch \
#     --gres=gpu:nvidia_rtx_a6000:1 \
#     --job-name=af3-s2-example1-nvidia_rtx_a6000-r1 stage2.sh
#
# Results go to output/stage2/<gpu>/r<repeat>/, so runs on different GPUs and
# repeats don't overwrite each other or the stage 1 output.
#
# gpu: two nodes with 2 NVIDIA RTX A6000 (48 GB) each, and one node with an
# NVIDIA GeForce RTX 2080 Ti (11 GB); 12-hour maximum time limit and only 2 GB
# of memory by default, so the cores and memory are requested above.

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
  echo "Elapsed seconds: $SECONDS"
}
trap print_elapsed EXIT

# Stage 1 wrote its output to output/ in the example directory.
export AF3_OUTPUT_DIR=${AF3_OUTPUT_DIR:-$SLURM_SUBMIT_DIR/output}

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

# The GPU Slurm gave us, as reported by the driver.
AF3_GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
AF3_GPU_MEMORY=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader | head -n 1)
compute_cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n 1)
# Label for the results directory and the log, e.g. nvidia_rtx_a6000.
export AF3_GPU=${AF3_GPU:-$(echo "$AF3_GPU_NAME" | tr '[:upper:] ' '[:lower:]_')}
export AF3_REPEAT=${AF3_REPEAT:-1}

# GPUs below compute capability 8.0, such as the RTX 2080 Ti (7.5), can't run
# the default Triton flash attention. Use the XLA one there, and keep the
# image's XLA_FLAGS while turning off the XLA pass that upstream says gives
# wrong results on these GPUs. See docs/performance.md in the AlphaFold 3
# repository.
AF3_ATTENTION=triton
if (( ${compute_cap%%.*} < 8 )); then
  AF3_ATTENTION=xla
  export APPTAINERENV_XLA_FLAGS="--xla_gpu_enable_triton_gemm=false --xla_disable_hlo_passes=custom-kernel-fusion-rewriter"
fi

# Machine-readable header for ../collect_results.py.
echo "Benchmark example: $(basename "$SLURM_SUBMIT_DIR")"
echo "Benchmark gpu: $AF3_GPU"
echo "Benchmark gpu name: $AF3_GPU_NAME"
echo "Benchmark gpu memory: $AF3_GPU_MEMORY"
echo "Benchmark repeat: $AF3_REPEAT"
echo "Benchmark attention: $AF3_ATTENTION"
echo "Benchmark node: $(hostname -s)"
echo "Benchmark job id: ${SLURM_JOB_ID:-none}"
echo "Benchmark start: $(date -Is)"

export AF3_RESULTS_DIR=$AF3_OUTPUT_DIR/stage2/$AF3_GPU/r$AF3_REPEAT
mkdir -p "$AF3_RESULTS_DIR"

# Node-local scratch and JAX cache in /tmp, removed when the script exits, so
# every run compiles the model from scratch and the timings are comparable.
# Set AF3_SCRATCH to use (and keep) another directory.
cleanup=:
if [[ -z ${AF3_SCRATCH:-} ]]; then
  export AF3_SCRATCH=/tmp/$USER-af3-${SLURM_JOB_ID:-$$}
  cleanup='rm -rf "$AF3_SCRATCH"'
fi
export AF3_JAX_CACHE_DIR=${AF3_JAX_CACHE_DIR:-$AF3_SCRATCH/jax_cache}
mkdir -p "$AF3_SCRATCH/output" "$AF3_SCRATCH/tmp" "$AF3_JAX_CACHE_DIR"

# Copy results from scratch to $AF3_RESULTS_DIR when the script exits, even on failure.
trap 'rsync -a "$AF3_SCRATCH/output/" "$AF3_RESULTS_DIR/"; '"$cleanup"'; print_elapsed' EXIT

export APPTAINERENV_TMPDIR="$AF3_SCRATCH/tmp"

run_alphafold \
  --json_path="$AF3_DATA_JSON" \
  --model_dir="$AF3_WEIGHTS" \
  --output_dir="$AF3_SCRATCH/output" \
  --jax_compilation_cache_dir="$AF3_JAX_CACHE_DIR" \
  --flash_attention_implementation="$AF3_ATTENTION" \
  --norun_data_pipeline
