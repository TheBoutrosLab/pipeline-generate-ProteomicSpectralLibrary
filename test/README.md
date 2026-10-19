# Integration test

Copy `.env-template` to `.env` at the repository root and set `TEST_DATA_DIR`. Fill in `mzml_csv`, `idxml_csv`, `psm_tsv`, and `peptide_tsv` in `test/test-integration-EasyPQP/test.config` with paths to matching test data. The two CSVs may contain `$TEST_DATA_DIR` or `${TEST_DATA_DIR}` in their file paths; nf-test expands those references into temporary copies before running the pipeline. This case sets `fractionated = true`: the mzML CSV should list at least two fractions for one sample and the idXML CSV should list that sample's merged idXML. IDRipper must be able to identify the source run of each PSM so its split filenames match the mzML basenames.

Inside a Slurm job, run this command from the repository root:

```bash
bash test/run-nftest.sh test-integration-EasyPQP
```

The runner writes temporary files and outputs under `/scratch/$SLURM_JOB_ID/test-integration-EasyPQP`. The case uses the pipeline's default EasyPQP container and publishes the per-run pickles for inspection.
