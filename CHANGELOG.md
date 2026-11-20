# Changelog

All notable changes to the generate-ProteomicSpectralLibrary pipeline are recorded here.

## [Unreleased]

## [1.1.1] - 2026-11-20

### Changed

- Migrate the pipeline license from GPL to BSD 3-Clause and update license documentation; shared code and third-party tools retain their respective licenses.

## [1.1.0] - 2026-11-10

### Added

- Build EasyPQP libraries separately for each offline fraction, then publish one TSV with fraction-specific fragment rows.

### Removed

- Remove synthetic Nextflow stub commands from pipeline processes.

## [1.0.2] - 2026-11-03

### Fixed

- Pass PSM and peak pickle files separately to EasyPQP when the cohort has only one converted run.

## [1.0.1] - 2026-10-24

### Fixed

- Keep individual process logs in `process-log/` after successful runs instead of archiving and deleting the directory.

## [1.0.0] - 2026-10-19

### Added

- Split merged sample idXMLs by fraction with IDRipper, then convert each matched mzML run to EasyPQP PSM and peak pickle files.
- Name per-run PSM and peak pickles after the mzML basename so EasyPQP can pair them during library generation.
- Combine all converted runs with cohort-wide PSM and peptide reports into one spectral library.
- Add versioned outputs, SHA-512 checksum, container profiles, resources, input validation, and stub workflow fixtures.

[1.0.0]: https://github.com/TheBoutrosLab/pipeline-generate-ProteomicSpectralLibrary/releases/tag/v1.0.0
[1.0.1]: https://github.com/TheBoutrosLab/pipeline-generate-ProteomicSpectralLibrary/compare/v1.0.0...v1.0.1
[1.0.2]: https://github.com/TheBoutrosLab/pipeline-generate-ProteomicSpectralLibrary/compare/v1.0.1...v1.0.2
[1.1.0]: https://github.com/TheBoutrosLab/pipeline-generate-ProteomicSpectralLibrary/compare/v1.0.2...v1.1.0
[1.1.1]: https://github.com/TheBoutrosLab/pipeline-generate-ProteomicSpectralLibrary/compare/v1.1.0...v1.1.1
[unreleased]: https://github.com/TheBoutrosLab/pipeline-generate-ProteomicSpectralLibrary/compare/v1.1.1...HEAD
