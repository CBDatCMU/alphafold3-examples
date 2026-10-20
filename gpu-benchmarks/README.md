# Stage 2 GPU benchmarks

Times stage 2 (inference) of the 14 examples on each GPU type in the `gpu`
partition: NVIDIA RTX A6000 (`nvidia_rtx_a6000`) and NVIDIA GeForce RTX 2080 Ti
(`nvidia_geforce_rtx_2080_ti`).

Both stages run on `gpu`. Stage 1 uses only the nodes' CPUs and runs once per
example; stage 2 is then submitted once per GPU type and repeat. The
`stage1.sh` and `stage2.sh` scripts are the same in every example directory.

## Hardware

GPU partition with 3 nodes. Time limit 12 hours, default memory 2 GB per node,
and up to 4 jobs can share a node.

| Node | GPUs | GPU memory | Compute capability | CPUs | Memory |
| --- | --- | ---: | ---: | ---: | ---: |
| `lanec2-4-22` | 2 × NVIDIA RTX A6000 | 48 GB each | 8.6 | 64 | 192 GB |
| `lanec2-4-24` | 2 × NVIDIA RTX A6000 | 48 GB each | 8.6 | 64 | 192 GB |
| `lanec2-4-5` | 1 × NVIDIA GeForce RTX 2080 Ti | 11 GB | 7.5 | 40 | 256 GB |

The 2 GB default is far too small for AlphaFold 3, so both scripts request
their cores and memory explicitly:

| Stage | Request | Time limit |
| --- | --- | --- |
| 1: data pipeline | 16 cores, 64 GB of memory, no GPU | 12 hours |
| 2: inference | 1 GPU, 8 cores, 64 GB of memory | 1 hour |

Stage 1 runs the four protein MSA searches at the same time, with 4 cores each
(`--jackhmmer_n_cpu=4`, `--nhmmer_n_cpu=4`). Both stages use `/tmp` on the node
as scratch and delete it when they finish.

## AlphaFold 3 files

There is no `alphafold3` module on this cluster, so the scripts run the
container directly with `apptainer`. They read these paths, which you can
override by setting the variable before `sbatch`:

| Variable | Default | Used by |
| --- | --- | --- |
| `AF3_IMAGE` | `~/alphafold3/singularity-alphafold3-v3.0.4.sif` | both stages |
| `AF3_DATABASES` | `~/alphafold3/databases` | stage 1 |
| `AF3_WEIGHTS` | `~/alphafold3/weights` | stage 2 |
| `AF3_SCRATCH` | `/tmp/$USER-af3-<jobid>`, deleted at the end | both stages |

## Run it

First run stage 1 once for every example:

```bash
for d in example*/; do (cd "$d" && sbatch stage1.sh); done
```

Each example's MSAs and templates go to `example<N>/output/<name>/`. When
those jobs finish, submit one stage 2 round (14 examples × 2 GPU types = 28
jobs), and wait until it finishes before submitting the next, so runs don't
share nodes with each other:

```bash
./submit.sh -r 1
# when round 1 is done (squeue -u $USER is empty):
./submit.sh -r 2
# ... up to -r 5
```

Add `-n` to print the `sbatch` commands without submitting. Pass example
directories to run only those (`./submit.sh -r 1 example1`), and set `GPUS` to
change the GPU types (`GPUS="nvidia_rtx_a6000" ./submit.sh -r 1`).

Runs that already succeeded or are still queued are skipped, so running the
same round again resubmits only the ones that failed. Examples without stage 1
output are skipped too.

The partition has 4 A6000s but only one 2080 Ti, so the 2080 Ti runs of a
round queue behind each other and take longest to finish.

Then collect the timings:

```bash
./collect_results.py
```

This writes `results.csv` with one row per run and prints the median inference
time per example and GPU. The `.out` logs and `output/` are not tracked by git,
so commit `results.csv` to keep the numbers.

## What gets recorded

Each job writes `example<N>/af3-s2-example<N>-<gpu>-r<repeat>-<jobid>.out`,
and its predicted structures go to `example<N>/output/stage2/<gpu>/r<repeat>/`.

| Column | Source |
| --- | --- |
| `inference_seconds` | AlphaFold 3's `Running model inference with seed ... took` line. Includes JAX compilation, which happens on every run because the cache is in the job's `/tmp` scratch, deleted at the end. Use this column to compare GPUs. |
| `featurisation_seconds` | `Featurising data ... took` (CPU work, not the GPU) |
| `elapsed_seconds` | The whole job: container start, featurisation, inference and copying results |
| `status` | `ok`, `oom`, `timeout`, `failed`, or `incomplete` (still running or killed) |
| `attention` | `triton`, or `xla` on the 2080 Ti (see below) |
| `gpu_name`, `gpu_memory`, `node` | From `nvidia-smi` and `hostname` on the node that ran the job |

## RTX 2080 Ti runs

The default Triton flash attention needs compute capability 8.0 or newer, and
the 2080 Ti has 7.5. When `nvidia-smi` reports a GPU below 8.0, `stage2.sh`
sets the two workarounds AlphaFold 3 needs there:

- `--flash_attention_implementation=xla`
- `--xla_disable_hlo_passes=custom-kernel-fusion-rewriter` in `XLA_FLAGS`, for
  a known numerical issue on these GPUs

The 2080 Ti times therefore measure the slower XLA attention, which is the only
way AlphaFold 3 runs on this GPU. Unified memory isn't enabled, so an input too
large for its 11 GB is recorded as `oom` rather than run more slowly.
