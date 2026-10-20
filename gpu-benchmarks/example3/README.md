# Example 3: Protein with ions (calmodulin + 4 Ca²⁺)

Predicts human calmodulin-1 (chain `A`, 149 residues, UniProt
[P0DP23](https://www.uniprot.org/uniprotkb/P0DP23)) with four calcium ions
(chains `B`–`E`, CCD `CA`), one for each EF-hand binding site. The input is
`examples/calmodulin_4calcium.json` from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One protein sequence (`A`) and four calcium ions (`B`–`E`) |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/calmodulin_4calcium/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example3
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/calmodulin_4calcium/`. The predicted structure is
`calmodulin_4calcium_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
