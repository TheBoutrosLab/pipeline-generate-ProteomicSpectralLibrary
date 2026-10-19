# Generate Proteomic Spectral Library

This Nextflow pipeline builds one cohort spectral library with [EasyPQP](https://github.com/grosenberger/easypqp) 0.1.59. For fractionated samples, it splits each merged idXML by source run with OpenMS IDRipper and matches the split files to the mzML fractions. Single-fraction samples use their idXML directly. EasyPQP converts each matched run to PSM and peak pickles, then combines them using the cohort-wide `psm.tsv` and `peptide.tsv` reports.

## How to run

1. Copy [config/template.config](config/template.config) and set the input and output paths.
2. Prepare the [mzML CSV](input/mzml.csv) with one run or fraction per row and the [idXML CSV](input/idxml.csv) with one idXML per sample. Set `fractionated = true` when a sample has multiple mzML fractions.
3. Run:

   ```bash
   nextflow run main.nf -c /path/to/your.config -profile apptainer
   ```

The `standard` and `docker` profiles use Docker; `apptainer` uses Apptainer. Use `-resume` to reuse completed conversions when rerunning the library step.

## Inputs

The mzML CSV requires these columns and may include others:

```csv
sample_name,fraction_id,mzML
sample-a,1,/data/sample-a-fraction-1.mzML
sample-a,2,/data/sample-a-fraction-2.mzML
```

The idXML CSV requires these columns and may include others:

```csv
sample_name,idXML
sample-a,/data/sample-a_ProtLoom.idXML
```

`sample_name` identifies a biological sample and may appear on several mzML rows. Each `(sample_name, fraction_id)` pair must be unique. The idXML CSV must have exactly one row for every sample in the mzML CSV. Row order does not matter. With `fractionated = false` (the default), every sample must have exactly one mzML row and its idXML goes directly to EasyPQP. With `fractionated = true`, IDRipper splits only samples with multiple mzML rows; samples with one row still use their idXML directly. Each split idXML must match exactly one mzML basename, using the same basename or that basename followed by an underscore and suffix. The workflow stops if a fraction has no match or multiple matches. Relative file paths are resolved from their respective CSV directories. mzML basenames must be unique across the experiment and cannot contain additional dots because EasyPQP parses spectrum names on dots. Use the unfiltered ProtLoom idXML from the validation pipeline; the cohort TSV reports contain the accepted PSMs and peptides at the desired FDR cutoff.

The `psm_tsv` and `peptide_tsv` parameters point to the cohort-level EasyPQP reports exported by `pipeline-validate-ProteomicPSM`. The required TSV columns are `Spectrum`, `Spectrum File`, `Peptide` for the PSM report and `Peptide`, `Gene`, `Protein ID` for the peptide report. Spectrum file names must match the mzML basenames in the mzML CSV.

Set `idxml_score_type` to the exact primary score type or PeptideHit metadata key containing the desired score. Set `easypqp_score_type` to its meaning, exactly `PEP` or `q-value`. The pipeline first uses the primary score when its type matches; otherwise it reads the named hit metadata. It requires a finite score from 0 to 1 for every hit and writes a temporary EasyPQP-compatible idXML without changing the source. The defaults select the `ProtLoom PEP` primary score and label it `PEP`. If the input keeps a different primary score, set `idxml_score_type = 'protloom_pep'` to read ProtLoom's hit metadata instead. The input's `higher_score_better` value is preserved; because PEP and q-value are lower-is-better, an input marked higher-is-better is rejected rather than silently changed. Do not label a q-value as PEP: EasyPQP accepts `q-value`, but its idXML parser sets the separate PEP field to zero in that case.

| Parameter | Required | Description |
| --- | --- | --- |
| `dataset_id` | Yes | Safe cohort name for the output directory and library filename. |
| `mzml_csv` | Yes | CSV of `sample_name`, `fraction_id`, and mzML path for each run. |
| `idxml_csv` | Yes | CSV of `sample_name` and merged idXML path for each sample. |
| `fractionated` | No | Enable multiple mzML fractions per sample and IDRipper splitting; default `false`. |
| `idxml_score_type` | No | Exact primary score type or hit metadata key to read; default `ProtLoom PEP`. |
| `easypqp_score_type` | No | Meaning of the selected score: `PEP` or `q-value`; default `PEP`. |
| `psm_tsv` | Yes | Cohort-level accepted PSM report. |
| `peptide_tsv` | Yes | Cohort-level accepted peptide and protein report. |
| `output_dir` | Yes | Root output directory. |
| `save_intermediate_files` | No | Publish per-run pickle files; default `false`. |
| `work_dir` | No | Nextflow work directory. Use scratch space for large mzML runs. |
| `docker_image_easypqp` | No | EasyPQP image; default `ghcr.io/theboutroslab/easypqp:0.1.59`. |
| `docker_image_openms` | No | IDRipper image; default `ghcr.io/theboutroslab/openms-thirdparty:3.5.0`. |

## Pipeline steps

1. When `fractionated = true`, `split_idXML` runs IDRipper once per multi-fraction sample, then matches each split idXML to a fraction's mzML basename. Single-fraction samples bypass this step.
2. `set_EasyPQP_idXML_score` uses `SetIdXMLPrimaryScore.py` to write a separate idXML with the selected primary score for each fraction. The source script is mounted read-only from the pipeline's `src` directory.
3. `convert_EasyPQP` runs once per matched fraction with `easypqp convert --pepxml --spectra --psms --peaks`. The pickle filenames use the mzML basename, which EasyPQP uses to pair peaks with PSMs during library generation.
4. `library_EasyPQP` waits for all conversions, then runs once with every `.psmpkl` and `.peakpkl` plus `--psmtsv` and `--peptidetsv`. With both reports present, EasyPQP uses their PSM selection and protein labels instead of recalculating its own peptide and protein FDR.

The workflow is shown in the [SVG schematic](docs/pipeline-flow.svg).

## Outputs

Results are written under `<output_dir>/generate-ProteomicSpectralLibrary-<version>/<dataset_id>/`.

| Output | Description |
| --- | --- |
| `output/EasyPQP/<dataset_id>_library.tsv` | Cohort spectral library. |
| `output/EasyPQP/<dataset_id>_library.tsv.sha512` | SHA-512 checksum for the library. |
| `output/EasyPQP/easypqp_*_reference_run.tsv` | RT or ion-mobility reference run, when generated. |
| `output/EasyPQP/easypqp_*_report.pdf` | EasyPQP calibration report, when generated. |
| `intermediate/IDRipper/<sample_name>/split/*.idXML` | Fraction-specific idXMLs when `save_intermediate_files = true`. |
| `intermediate/EasyPQP/<sample_name>_<fraction_id>/<input_basename>_EasyPQP.idXML` | EasyPQP-compatible idXML when `save_intermediate_files = true`. |
| `intermediate/EasyPQP/<sample_name>_<fraction_id>/*.pkl` | Per-fraction PSM and peak pickles when `save_intermediate_files = true`. |
| `log-*/` | Nextflow trace, report, timeline, parameters, and process logs. |

## Testing

The [nf-test integration case](test/README.md) is configured for Slurm. Copy `.env-template` to `.env`, set `TEST_DATA_DIR`, and fill the four input paths in `test/test-integration-EasyPQP/test.config` before running it.

## References and discussions

- [EasyPQP](https://github.com/grosenberger/easypqp)
- [Boutros Lab EasyPQP image](https://github.com/TheBoutrosLab/docker-EasyPQP)
- [Issue tracker](https://github.com/TheBoutrosLab/pipeline-generate-ProteomicSpectralLibrary/issues)
- [Contributors](https://github.com/TheBoutrosLab/pipeline-generate-ProteomicSpectralLibrary/graphs/contributors)

## License

This pipeline is licensed under GNU GPL version 2 or later. See [LICENSE](LICENSE).
