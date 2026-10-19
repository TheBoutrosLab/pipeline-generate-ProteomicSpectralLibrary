/** Extract PSM metadata and experimental peaks from one identified mzML run. */
process convert_EasyPQP {
    container params.docker_image_easypqp

    publishDir path: "${params.output_dir_base}/intermediate/EasyPQP/${sample_name}",
        mode: 'copy',
        enabled: params.save_intermediate_files,
        pattern: '*pkl'

    input:
        tuple val(sample_name), path(id_file), path(mzml)

    output:
        tuple val(sample_name),
            path("${mzml.baseName.replaceFirst(/_(?:un)?calibrated$/, '')}.psmpkl"),
            path("${mzml.baseName.replaceFirst(/_(?:un)?calibrated$/, '')}.peakpkl"),
            emit: converted

    script:
        def spectra_name = mzml.baseName.replaceFirst(/_(?:un)?calibrated$/, '')
        """
        set -euo pipefail
        easypqp convert \\
            --pepxml "${id_file}" \\
            --spectra "${mzml}" \\
            --psms "${spectra_name}.psmpkl" \\
            --peaks "${spectra_name}.peakpkl"
        """

    stub:
        def spectra_name = mzml.baseName.replaceFirst(/_(?:un)?calibrated$/, '')
        """
        printf 'stub PSMs\\n' > "${spectra_name}.psmpkl"
        printf 'stub peaks\\n' > "${spectra_name}.peakpkl"
        """
}
