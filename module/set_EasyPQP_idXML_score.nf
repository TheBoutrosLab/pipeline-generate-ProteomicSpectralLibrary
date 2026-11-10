/** Select and validate PSM scores in a copy of each fraction's idXML. */
process set_EasyPQP_idXML_score {
    container params.docker_image_easypqp
    containerOptions params.project_script_mount_options

    publishDir path: "${params.output_dir_base}/intermediate/EasyPQP/${sample_name}",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: '*_EasyPQP.idXML'

    input:
        tuple val(sample_name), val(fraction_id), path(id_file), path(mzml)

    output:
        tuple val(sample_name), val(fraction_id),
            path("${id_file.baseName}_EasyPQP.idXML"), path(mzml), emit: prepared

    script:
        def output_name = "${id_file.baseName}_EasyPQP.idXML"
        """
        set -euo pipefail
        python3 "${projectDir}/src/SetIdXMLPrimaryScore.py" \\
            --input "${id_file}" \\
            --output "${output_name}" \\
            --source-score '${params.idxml_score_type}' \\
            --target-score '${params.easypqp_score_type}'
        """
}
