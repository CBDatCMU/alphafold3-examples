# Example 5: Covalent ligand (KRAS G12C + sotorasib)

Predicts human KRAS4B with the G12C mutation (chain `A`, 189 residues, UniProt
[P01116](https://www.uniprot.org/uniprotkb/P01116)) covalently bound to the
inhibitor sotorasib (chain `B`, CCD `MOV`). The covalent bond between Cys12 `SG`
and the ligand is given in `bondedAtomPairs`. The input is
`examples/kras_g12c_sotorasib.json` from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One protein (`A`), one CCD ligand (`B`), and a covalent bond in `bondedAtomPairs` |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/KRAS_G12C_sotorasib_covalent/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example5
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/KRAS_G12C_sotorasib_covalent/`. The predicted structure is
`KRAS_G12C_sotorasib_covalent_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
