/** Build one library per fraction across all samples using cohort-wide filters. */
process library_EasyPQP {
    container params.docker_image_easypqp

    publishDir path: "${params.output_dir_base}/intermediate/EasyPQP/libraries/${fraction_id}",
        mode: 'copy'

    publishDir path: "${params.output_dir_base}/output/EasyPQP",
        mode: 'copy',
        enabled: !params.fractionated,
        pattern: 'easypqp_*'

    input:
        tuple val(dataset_id), val(fraction_id), path(psm_pickles), path(peak_pickles)
        path(psm_tsv)
        path(peptide_tsv)

    output:
        tuple val(fraction_id), path("${dataset_id}_${fraction_id}_library.tsv"), emit: library
        path('easypqp_*_reference_run.tsv'), optional: true, emit: references
        path('easypqp_*_report.pdf'), optional: true, emit: reports

    script:
        def convertedFiles = [psm_pickles, peak_pickles]
            .collectMany { it instanceof List ? it : [it] }
            .collect { "\"${it}\"" }.join(' ')
        """
        set -euo pipefail
        easypqp library \\
            --out "${dataset_id}_${fraction_id}_library.tsv" \\
            --psmtsv "${psm_tsv}" \\
            --peptidetsv "${peptide_tsv}" \\
            ${convertedFiles}
        """
}
