# Example 8: Glycoprotein (RNase B + N-glycan)

Predicts bovine ribonuclease B (chain `A`, 124 residues, UniProt
[P61823](https://www.uniprot.org/uniprotkb/P61823)) with a core N-linked glycan
(Man3GlcNAc2, chain `B`) attached to Asn34. The glycan is a multi-residue ligand
(`NAG`, `NAG`, `BMA`, `MAN`, `MAN`) whose glycosidic bonds and attachment to the
protein are given in `bondedAtomPairs`. The input is
`examples/rnaseb_glycosylated.json` from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One protein (`A`), one glycan ligand (`B`), and bonds in `bondedAtomPairs` |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/RNaseB_glycosylated/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example8
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/RNaseB_glycosylated/`. The predicted structure is
`RNaseB_glycosylated_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
