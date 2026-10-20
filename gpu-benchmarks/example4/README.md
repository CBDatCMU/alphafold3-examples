# Example 4: Phosphorylated protein (ERK2 pThr185/pTyr187)

Predicts human ERK2/MAPK1 (chain `A`, 360 residues, UniProt
[P28482](https://www.uniprot.org/uniprotkb/P28482)) with its activation loop
dually phosphorylated: phosphothreonine at 185 (CCD `TPO`) and phosphotyrosine
at 187 (CCD `PTR`), given as `modifications` on the protein. The input is
`examples/erk2_phosphorylated.json` from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One protein sequence (`A`) with two post-translational modifications |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/ERK2_dual_phosphorylated/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example4
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/ERK2_dual_phosphorylated/`. The predicted structure is
`ERK2_dual_phosphorylated_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
