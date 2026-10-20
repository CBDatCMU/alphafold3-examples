# Example 6: Methylated double-stranded DNA

Predicts a 20-bp double-stranded DNA (chains `A` and `B`) with 5-methylcytosine
(CCD `5CM`) at every CpG site on both strands, given as `modifications` on each
DNA chain. DNA chains have no MSA, so stage 1 is quick. The input is
`examples/methylated_dna.json` from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: Two DNA strands (`A`, `B`) with 5-methylcytosine modifications |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/methylated_CpG_dsDNA/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example6
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/methylated_CpG_dsDNA/`. The predicted structure is
`methylated_CpG_dsDNA_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
