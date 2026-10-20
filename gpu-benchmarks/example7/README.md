# Example 7: Modified RNA (tRNA-like fragment)

Predicts a 25-nt tRNA-like RNA fragment (chain `A`) with three modified
nucleotides: 2'-O-methylguanosine (CCD `OMG`) at 4, pseudouridine (CCD `PSU`) at
13, and 5-methylcytidine (CCD `5MC`) at 18. The input is
`examples/modified_rna.json` from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One RNA sequence (`A`) with three modified nucleotides |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/modified_RNA_hairpin/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example7
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/modified_RNA_hairpin/`. The predicted structure is
`modified_RNA_hairpin_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
