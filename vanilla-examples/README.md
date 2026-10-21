# Vanilla examples

14 vanilla AlphaFold 3 examples, each run with 5 replicates. Each example runs
as two Slurm job arrays, using the `stage1.sh` and `stage2.sh` scripts in its
directory:

| Stage | Partition | What it does |
| --- | --- | --- |
| 1: data pipeline | `pool1` | CPU only: MSA and template search |
| 2: inference | `gpu` | Model inference on one GPU |

The job logs (`af3-data-<jobid>_<replicate>.out`,
`af3-inference-<jobid>_<replicate>.out`) and the `output/` directories are
written to each example directory but are ignored by Git.

## Hardware

### CPU nodes that can run AlphaFold 3 (stage 1)

AlphaFold 3 needs a CPU with AVX instructions. The JAX library in the
container checks for AVX as soon as it loads, so on an older node the job
fails within about 10 seconds with:

```
RuntimeError: This version of jaxlib was built using AVX instructions, which
your CPU and/or operating system do not support.
```

AVX is part of the processor, not a setting, so it can't be turned on. The
Xeon E5520, E5620 and E5645 nodes (2009–2010) don't have it and can't run
AlphaFold 3. Every other CPU node does. This was checked on each node on
2026-10-20.

| Partition | Who can submit | Time limit | Nodes | Nodes with AVX | Can run AlphaFold 3 |
| --- | --- | --- | ---: | ---: | --- |
| `pool1` | everyone | 3 days (default 8 hours) | 35 | 23 | Yes, excluding 12 nodes |
| `pool3-bigmem` | everyone | 4 days 4 hours (default 8 hours) | 2 | 1 | Yes, on `lanec2-0-12` only |
| `model1` | `queue_model1` | unlimited | 6 | 0 | **No** |
| `model2` | `queue_model2` | unlimited | 2 | 2 | Yes |
| `model3` | `queue_model3` | 4 days | 1 | 1 | Yes |
| `rs1` | `queue_rs1` | unlimited | 6 | 0 | **No** |
| `rs2` | `queue_rs1` | unlimited | 1 | 1 | Yes |
| `zbj1` | `queue_zbj1` | unlimited | 2 | 2 | Yes |
| `zbj1-bigmem` | `queue_zbj1` | unlimited | 1 | 1 | Yes |

Up to 4 jobs can share a node in every one of these partitions. Several nodes
are in more than one partition:

| Nodes | CPU | AVX | Cores (sockets × cores × threads) | Memory | Partitions |
| --- | --- | --- | --- | ---: | --- |
| `lanec2-0-[24-28]` | Intel Xeon E5520 | **No** | 8 (2 × 4 × 1) | 32 GB | `pool1`, `rs1` |
| `lanec2-0-30` | Intel Xeon E5620 | **No** | 8 (2 × 4 × 1) | 24 GB | `pool1`, `rs1` |
| `lanec2-1-[23-24,26]` | Intel Xeon E5645 | **No** | 12 (2 × 6 × 1) | 32 GB | `pool1`, `model1` |
| `lanec2-1-[27-29]` | Intel Xeon E5620 | **No** | 8 (2 × 4 × 1) | 24 GB | `pool1`, `model1` |
| `lanec2-1-35` | Intel Xeon E5520 | **No** | 8 (2 × 4 × 1) | 128 GB | `pool3-bigmem` |
| `lanec2-0-4`, `lanec2-1-[14-16]` | Intel Xeon E5-2450 | Yes | 16 (2 × 8 × 1) | 48 GB | `pool1` |
| `lanec2-0-[5-6]`, `lanec2-1-[17-18]` | Intel Xeon E5-2450 | Yes | 32 (2 × 8 × 2) | 48 GB | `pool1` |
| `lanec2-3-[36,40]` | Intel Xeon E5-2440 v2 | Yes | 16 (2 × 8 × 1) | 48 GB | `pool1`, `model2` |
| `lanec2-0-[16,18]` | AMD Opteron 6348 | Yes | 24 (2 × 12 × 1) | 64 GB | `pool1`, `zbj1` |
| `lanec2-0-12` | AMD Opteron 6320 | Yes | 32 (4 × 8 × 1) | 256 GB | `pool3-bigmem`, `zbj1-bigmem` |
| `lanec2-0-[29,33-36]` | Intel Xeon Silver 4214 | Yes | 48 (2 × 12 × 2) | 256 GB | `pool1` |
| `lanec2-1-[2-6]` | Intel Xeon E5-2680 v4 | Yes | 56 (2 × 14 × 2) | 128 GB | `pool1` |
| `lanec2-2-22` | Intel Xeon E5-2630 v4 | Yes | 40 (2 × 10 × 2) | 512 GB | `pool1`, `rs2` |
| `lanec2-2-31` | Intel Xeon Gold 6230 | Yes | 80 (2 × 20 × 2) | 128 GB | `model3` |

On `pool1` and `pool3-bigmem`, exclude the nodes without AVX when you submit:

```bash
sbatch --exclude='lanec2-0-[24-28,30],lanec2-1-[23-24,26-29,35]' stage1.sh
```

The nodes differ a lot in size, so stage 1 should request its cores and
memory explicitly (`--cpus-per-task`, `--mem`) rather than rely on the 3 GB
default, which is too small for the data pipeline. Stage 1 asks for 8 cores
and 23 GB (23552 MB), which fits every node above. The smallest nodes with AVX
have 16 cores and 48 GB.

### `gpu` (stage 2)

GPU partition with 3 nodes. Time limit 12 hours, default memory 2 GB per node,
and up to 4 jobs can share a node.

| Node | GPUs | GPU memory | CPUs | Sockets × cores × threads | Memory |
| --- | --- | ---: | ---: | --- | ---: |
| `lanec2-4-22` | 2 × NVIDIA RTX A6000 | 48 GB each | 64 | 2 × 16 × 2 | 192 GB |
| `lanec2-4-24` | 2 × NVIDIA RTX A6000 | 48 GB each | 64 | 2 × 16 × 2 | 192 GB |
| `lanec2-4-5` | 1 × NVIDIA GeForce RTX 2080 Ti | 11 GB | 40 | 2 × 10 × 2 | 256 GB |

Stage 2 requests an A6000 (`--gres=gpu:nvidia_rtx_a6000:1`). The RTX 2080 Ti
has only 11 GB of memory and compute capability 7.5, so it is suited only to
small inputs. When `stage2.sh` runs on it, the script switches AlphaFold 3 to
XLA flash attention (`--flash_attention_implementation=xla`), because the
default Triton implementation needs compute capability 8.0.

## Job resources

| Stage | Partition | Request | Time limit |
| --- | --- | --- | --- |
| 1: data pipeline | `pool1` | 8 cores, 23 GB of memory | 12 hours |
| 2: inference | `gpu` | 1 RTX A6000, 8 cores, 64 GB of memory | 2 hours |

Stage 1 runs the four protein MSA searches at the same time, with 2 cores each
(`--jackhmmer_n_cpu=2`, `--nhmmer_n_cpu=2`). Every example input is small
(at most 360 residues per chain), so 23 GB is enough. For a larger input of
your own, raise `--mem` at submission, e.g. `sbatch --mem=40G stage1.sh`;
that limits the job to the nodes with at least 48 GB. Both stages use `/tmp` on the node
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

The genetic databases must be complete and the model weights (`af3.bin.zst`)
must be in `AF3_WEIGHTS` before the jobs can succeed.

## Run all examples

`submit.sh` submits stage 1 and stage 2 for every example, each as a job array
of 5 replicates:

```bash
./submit.sh                       # all examples, replicates 1-5
./submit.sh -n                    # dry run: print the sbatch commands
./submit.sh -r 1 example1 example2
./submit.sh -g nvidia_geforce_rtx_2080_ti example7   # small input on the 2080 Ti
```

Replicates that already have a predicted structure, and examples with jobs
still queued or running, are skipped, so rerunning the same command retries
only failed replicates. See the comments in `submit.sh` for all options.
