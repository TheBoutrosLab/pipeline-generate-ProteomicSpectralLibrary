# Changelog

All notable changes to the generate-ProteomicSpectralLibrary pipeline are recorded here.

## [Unreleased] - 2026-10-21

### Fixed
- Keep individual process logs in `process-log/` after successful runs instead of archiving and deleting the directory.

## [1.0.0] - 2026-10-19

### Added
- Split merged sample idXMLs by fraction with IDRipper, then convert each matched mzML run to EasyPQP PSM and peak pickle files.
- Name per-run PSM and peak pickles after the mzML basename so EasyPQP can pair them during library generation.
- Combine all converted runs with cohort-wide PSM and peptide reports into one spectral library.
- Add versioned outputs, SHA-512 checksum, container profiles, resources, input validation, and stub workflow fixtures.
