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

### `pool1` (stage 1)

CPU-only partition with 35 nodes. Time limit 3 days (default 8 hours),
default memory 3 GB per node, and up to 4 jobs can share a node.

| Nodes | Count | CPUs per node | Sockets × cores × threads | Memory per node |
| --- | ---: | ---: | --- | ---: |
| `lanec2-0-[24-28]` | 5 | 8 | 2 × 4 × 1 | 32 GB |
| `lanec2-0-30`, `lanec2-1-[27-29]` | 4 | 8 | 2 × 4 × 1 | 24 GB |
| `lanec2-1-[23-24,26]` | 3 | 12 | 2 × 6 × 1 | 32 GB |
| `lanec2-0-4`, `lanec2-1-[14-16]`, `lanec2-3-[36,40]` | 6 | 16 | 2 × 8 × 1 | 48 GB |
| `lanec2-0-[16,18]` | 2 | 24 | 2 × 12 × 1 | 64 GB |
| `lanec2-0-[5-6]`, `lanec2-1-[17-18]` | 4 | 32 | 2 × 8 × 2 | 48 GB |
| `lanec2-2-22` | 1 | 40 | 2 × 10 × 2 | 512 GB |
| `lanec2-0-[29,33-36]` | 5 | 48 | 2 × 12 × 2 | 256 GB |
| `lanec2-1-[2-6]` | 5 | 56 | 2 × 14 × 2 | 128 GB |

The nodes differ a lot in size, so stage 1 should request its cores and
memory explicitly (`--cpus-per-task`, `--mem`) rather than rely on the 3 GB
default, which is too small for the data pipeline. The smallest nodes have
8 cores and 24059 MB that Slurm can allocate, so stage 1 asks for 8 cores and
23 GB (23552 MB), which fits every one of the 35 nodes.

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
