# Example 2: protein heterodimer (barnase–barstar)

Predicts the structure of a heterodimer of two different proteins from
*Bacillus amyloliquefaciens*: the ribonuclease barnase (chain `A`, 110 residues,
UniProt [P00648](https://www.uniprot.org/uniprotkb/P00648)) bound to its
inhibitor barstar (chain `B`, 89 residues, UniProt
[P11540](https://www.uniprot.org/uniprotkb/P11540)). The input is
`examples/barnase_barstar.json` from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: two protein sequences, barnase (`A`) and barstar (`B`) |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/barnase_barstar_complex/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example2
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/barnase_barstar_complex/`. The predicted structure is
`barnase_barstar_complex_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
