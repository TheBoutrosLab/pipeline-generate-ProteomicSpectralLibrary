# Integration test

Copy `.env-template` to `.env` at the repository root and set `TEST_DATA_DIR` to the matching E. coli fixtures. The two CSVs may contain `$TEST_DATA_DIR` or `${TEST_DATA_DIR}` in their file paths; nf-test expands those references into temporary copies before running the pipeline. The configured NFTest case uses `fractionated = false` and exercises the established single-library route.

Inside a Slurm job, run this command from the repository root:

```bash
bash test/run-nftest.sh test-integration-EasyPQP
```

The runner writes temporary files and outputs under `/scratch/$SLURM_JOB_ID/test-integration-EasyPQP`. The case uses the pipeline's default EasyPQP container and publishes the per-run pickles for inspection.

A full fractionated integration run requires matched cluster mzML, merged idXML, and cohort PSM/peptide fixtures.
