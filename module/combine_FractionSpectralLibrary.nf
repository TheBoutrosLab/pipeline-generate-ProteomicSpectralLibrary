/** Publish one cohort TSV from the fraction-specific EasyPQP libraries. */
process combine_FractionSpectralLibrary {
    container params.docker_image_easypqp
    containerOptions params.project_script_mount_options

    publishDir path: "${params.output_dir_base}/output/EasyPQP", mode: 'copy'

    input:
        tuple val(dataset_id), val(fraction_ids), path(libraries)

    output:
        path("${dataset_id}_library.tsv"), emit: library
        path("${dataset_id}_library.tsv.sha512"), emit: checksum

    script:
        def libraryFiles = libraries instanceof List ? libraries : [libraries]
        def annotationFlag = params.fractionated ? '--annotate' : ''
        def inputs = fraction_ids.indices.collect { index ->
            "--fraction '${fraction_ids[index]}:${libraryFiles[index]}'"
        }.join(' ')
        """
        set -euo pipefail
        python3 "${projectDir}/src/CombineFractionLibraries.py" \\
            --output "${dataset_id}_library.tsv" \\
            ${annotationFlag} \\
            ${inputs}
        sha512sum "${dataset_id}_library.tsv" > "${dataset_id}_library.tsv.sha512"
        """
}
