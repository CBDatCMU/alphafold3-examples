# Example 1: protein homodimer (PDB 2PV7)

Predicts the structure of a homodimer: two copies (chains `A` and `B`) of the
same 298-residue protein from PDB entry
[2PV7](https://www.rcsb.org/structure/2PV7). This is the example input from the
upstream AlphaFold 3 documentation.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: one protein sequence, used for chains `A` and `B` |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/2PV7/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example1
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/2PV7/`. The predicted structure is
`2PV7_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
