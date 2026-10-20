# Example 13: Protein–RNA complex (U1A + RNA hairpin)

Predicts the RRM1 domain of human U1A (chain `A`, 101 residues, UniProt
[P09012](https://www.uniprot.org/uniprotkb/P09012)) bound to the 21-nt U1 snRNA
stem-loop II hairpin (chain `B`), as in PDB
[1URN](https://www.rcsb.org/structure/1URN). The input is
`examples/u1a_rna_hairpin.json` from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One protein sequence (`A`) and one RNA sequence (`B`) |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/U1A_RNA_hairpin/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example13
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/U1A_RNA_hairpin/`. The predicted structure is
`U1A_RNA_hairpin_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
