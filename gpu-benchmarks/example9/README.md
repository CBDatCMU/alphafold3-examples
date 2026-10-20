# Example 9: Protein + ligand from SMILES (streptavidin–biotin)

Predicts core streptavidin from *Streptomyces avidinii* (chain `A`, 126
residues, UniProt [P22629](https://www.uniprot.org/uniprotkb/P22629)) bound to
D-biotin (chain `B`). The ligand is given as a SMILES string instead of a CCD
code. The input is `examples/streptavidin_biotin_smiles.json` from the upstream
AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One protein sequence (`A`) and one SMILES ligand (`B`) |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/streptavidin_biotin_smiles/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example9
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/streptavidin_biotin_smiles/`. The predicted structure is
`streptavidin_biotin_smiles_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
