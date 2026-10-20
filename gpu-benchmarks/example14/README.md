# Example 14: Protein monomer (ubiquitin)

Predicts human ubiquitin (chain `A`, 76 residues, UniProt
[P0CG48](https://www.uniprot.org/uniprotkb/P0CG48)), a single small protein. It
is the fastest example to run. The input is `examples/ubiquitin_monomer.json`
from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One protein sequence (`A`) |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/ubiquitin_monomer/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example14
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/ubiquitin_monomer/`. The predicted structure is
`ubiquitin_monomer_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
