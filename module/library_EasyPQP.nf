/** Combine every converted run using cohort-wide PSM and peptide filters. */
process library_EasyPQP {
    container params.docker_image_easypqp

    publishDir path: "${params.output_dir_base}/output/EasyPQP",
        mode: 'copy'

    input:
        tuple val(dataset_id), path(psm_pickles), path(peak_pickles)
        path(psm_tsv)
        path(peptide_tsv)

    output:
        path("${dataset_id}_library.tsv"), emit: library
        path("${dataset_id}_library.tsv.sha512"), emit: checksum
        path('easypqp_*_reference_run.tsv'), optional: true, emit: references
        path('easypqp_*_report.pdf'), optional: true, emit: reports

    script:
        def convertedFiles = [psm_pickles, peak_pickles]
            .collectMany { it instanceof List ? it : [it] }
            .collect { "\"${it}\"" }.join(' ')
        """
        set -euo pipefail
        easypqp library \\
            --out "${dataset_id}_library.tsv" \\
            --psmtsv "${psm_tsv}" \\
            --peptidetsv "${peptide_tsv}" \\
            ${convertedFiles}
        sha512sum "${dataset_id}_library.tsv" > "${dataset_id}_library.tsv.sha512"
        """

    stub:
        """
        printf 'ProteinId\\tPeptideSequence\\n' > "${dataset_id}_library.tsv"
        sha512sum "${dataset_id}_library.tsv" > "${dataset_id}_library.tsv.sha512"
        """
}
