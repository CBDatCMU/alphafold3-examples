# Example 10: Protein–DNA complex (TetR dimer + tetO)

Predicts a homodimer of the *E. coli* tetracycline repressor TetR class D
(chains `A` and `B`, 218 residues, UniProt
[P0ACT4](https://www.uniprot.org/uniprotkb/P0ACT4)) bound to its 20-bp tetO2
operator DNA (chains `C` and `D`). The input is `examples/tetr_dimer_dna.json`
from the upstream AlphaFold 3 repository.

## Files

| File | What it does |
| --- | --- |
| `fold_input.json` | Input: One protein sequence for chains `A` and `B`, and two DNA strands (`C`, `D`) |
| `stage1.sh` | Stage 1 on `gpu` (CPUs only): builds MSAs and finds templates |
| `stage2.sh` | Stage 2 on `gpu` (one GPU): predicts the structure and logs its timings |

## Run it

From this directory, run stage 1 once:

```bash
sbatch stage1.sh
```

It writes the MSAs and templates to `output/TetR_dimer_tetO_DNA/`. When it finishes,
benchmark stage 2 from the parent directory, one round at a time:

```bash
cd .. && ./submit.sh -r 1 example10
```

Watch the jobs with `squeue -u $USER`. Each stage 2 run writes its results to
`output/stage2/<gpu>/r<repeat>/TetR_dimer_tetO_DNA/`. The predicted structure is
`TetR_dimer_tetO_DNA_model.cif`.

See the [main README](../README.md) for how the benchmark works and how to
collect the timings.
