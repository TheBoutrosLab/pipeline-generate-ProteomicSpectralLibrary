/** Split one sample's merged idXML into source-run idXML files. */
process split_idXML {
    container params.docker_image_openms

    publishDir path: "${params.output_dir_base}/intermediate/IDRipper/${sample_name}",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: 'split/*.idXML'

    input:
        tuple val(sample_name), path(merged_idxml), val(fractions)

    output:
        tuple val(sample_name), val(fractions), path('split/*.idXML'), emit: split

    script:
        """
        set -euo pipefail
        mkdir -p split
        IDRipper -in "${merged_idxml}" -out split -threads ${task.cpus}
        """
}
