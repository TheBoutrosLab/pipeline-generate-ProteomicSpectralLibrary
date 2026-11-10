#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { convert_EasyPQP } from './module/convert_EasyPQP.nf'
include { library_EasyPQP } from './module/library_EasyPQP.nf'
include { split_idXML } from './module/split_idXML.nf'
include { set_EasyPQP_idXML_score } from './module/set_EasyPQP_idXML_score.nf'
include { combine_FractionSpectralLibrary } from './module/combine_FractionSpectralLibrary.nf'

/** Read one merged idXML per biological sample. */
def indexIdentifications(List rows, def csv) {
    if (!rows) {
        error "Input CSV has no samples: ${csv}"
    }

    def samples = [:]
    rows.each { row ->
        if (!row.keySet().containsAll(['sample_name', 'idXML'])) {
            error "${csv} must include sample_name,idXML columns"
        }

        def sampleName = row.sample_name?.trim()
        if (!(sampleName ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) ||
            sampleName in ['.', '..']) {
            error "Invalid sample_name in ${csv}: ${row.sample_name}"
        }
        if (samples.containsKey(sampleName)) {
            error "Duplicate sample_name in ${csv}: ${sampleName}"
        }

        def inputPath = row.idXML?.trim()
        if (!inputPath) {
            error "Missing idXML path for ${sampleName} in ${csv}"
        }
        def identification = file(inputPath.startsWith('/') ? inputPath : "${csv.parent}/${inputPath}")
        if (!identification.isFile() || !identification.name.toLowerCase().endsWith('.idxml')) {
            error "Missing or invalid idXML for ${sampleName}: ${identification}"
        }
        samples[sampleName] = identification
    }
    return samples
}

/** Read fraction mzMLs and match each sample to one merged idXML. */
def readSamples(String mzmlCsv, String idxmlCsv) {
    def spectraCsv = file(mzmlCsv)
    def identificationCsv = file(idxmlCsv)

    Channel.fromPath(spectraCsv).splitCsv(header: true).toList()
        .map { rows -> [rows: rows] }
        .combine(Channel.fromPath(identificationCsv).splitCsv(header: true).toList()
            .map { rows -> [rows: rows] })
        .map { spectraInput, identificationInput ->
            def identificationsBySample = indexIdentifications(identificationInput.rows, identificationCsv)
            def spectraBySample = [:].withDefault { [] }
            def rawNames = [] as Set
            if (!spectraInput.rows) {
                error "Input CSV has no fractions: ${spectraCsv}"
            }
            spectraInput.rows.each { row ->
                if (!row.keySet().containsAll(['sample_name', 'fraction_id', 'mzML'])) {
                    error "${spectraCsv} must include sample_name,fraction_id,mzML columns"
                }
                def sampleName = row.sample_name?.trim()
                def fractionId = row.fraction_id?.trim()
                if (!(sampleName ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) ||
                    sampleName in ['.', '..'] ||
                    !(fractionId ==~ /[A-Za-z0-9][A-Za-z0-9._-]*/) ||
                    fractionId in ['.', '..']) {
                    error "Invalid sample_name or fraction_id in ${spectraCsv}: ${row}"
                }
                if (spectraBySample[sampleName].any { it.fractionId == fractionId }) {
                    error "Duplicate fraction_id '${fractionId}' for sample '${sampleName}'"
                }
                def rawPath = row.mzML?.trim()
                if (!rawPath) {
                    error "Missing mzML path for ${sampleName}, fraction ${fractionId}"
                }
                def spectra = file(rawPath.startsWith('/') ? rawPath : "${spectraCsv.parent}/${rawPath}")
                if (!spectra.isFile() || !spectra.name.toLowerCase().endsWith('.mzml')) {
                    error "Missing or invalid mzML for ${sampleName}, fraction ${fractionId}: ${spectra}"
                }
                if (spectra.baseName.contains('.') || !rawNames.add(spectra.name.toLowerCase())) {
                    error "mzML names must be unique and have no dots before .mzML: ${spectra.name}"
                }
                spectraBySample[sampleName] << [fractionId: fractionId, mzml: spectra]
            }
            def missingIds = (spectraBySample.keySet() - identificationsBySample.keySet()).sort()
            def missingSpectra = (identificationsBySample.keySet() - spectraBySample.keySet()).sort()
            if (missingIds || missingSpectra) {
                error "CSV sample_name mismatch; missing idXML: ${missingIds}; missing mzML: ${missingSpectra}"
            }
            if (!params.fractionated && spectraBySample.any { name, fractions -> fractions.size() != 1 }) {
                error 'fractionated = false requires exactly one mzML row per sample_name'
            }
            def idPaths = [] as Set
            def runNames = [] as Set
            spectraBySample.keySet().sort().collect { sampleName ->
                def identification = identificationsBySample[sampleName]
                if (!idPaths.add(identification.toString())) {
                    error "Merged idXML is assigned to multiple samples: ${identification}"
                }
                spectraBySample[sampleName].each { fraction ->
                    def runName = "${sampleName}_${fraction.fractionId}"
                    if (!runNames.add(runName)) {
                        error "Fractions produce the same output name: ${runName}"
                    }
                }
                tuple(sampleName, identification,
                    spectraBySample[sampleName].sort { it.fractionId })
            }
        }
}

/** Require exactly one IDRipper output for every mzML basename. */
def matchFractions(String sampleName, List fractions, def splitFiles) {
    def candidates = splitFiles instanceof List ? splitFiles : [splitFiles]
    def used = [] as Set
    fractions.collect { fraction ->
        def prefix = fraction.mzml.baseName
        def matches = candidates.findAll { idxml ->
            idxml.baseName == prefix || idxml.baseName.startsWith("${prefix}_")
        }
        if (matches.size() != 1) {
            error "Expected one split idXML for ${sampleName}, fraction ${fraction.fractionId}, " +
                "mzML ${fraction.mzml.name}; found ${matches.size()}: ${matches*.name}"
        }
        if (!used.add(matches[0].toString())) {
            error "Split idXML matched multiple fractions: ${matches[0]}"
        }
        tuple("${sampleName}_${fraction.fractionId}", fraction.fractionId,
            matches[0], fraction.mzml)
    }
}

log.info """\
        =====================================================================
        G E N E R A T E   P R O T E O M I C   S P E C T R A L   L I B R A R Y
        =====================================================================
        Boutros Lab

        Pipeline: ${workflow.manifest.name} ${workflow.manifest.version}
        mzML CSV: ${params.mzml_csv}
        idXML CSV: ${params.idxml_csv}
        Fractionated: ${params.fractionated}
        idXML score: ${params.idxml_score_type} (${params.easypqp_score_type})
        Cohort reports: ${params.psm_tsv}, ${params.peptide_tsv}
        Output: ${params.output_dir_base}
        OpenMS image: ${params.docker_image_openms}
        EasyPQP image: ${params.docker_image_easypqp}
        """.stripIndent()

workflow {
    samples = readSamples(params.mzml_csv, params.idxml_csv)
    sampleRecords = samples.flatMap { it }

    if (params.fractionated) {
        singleFractions = sampleRecords
            .filter { sampleName, idxml, fractions -> fractions.size() == 1 }
            .map { sampleName, idxml, fractions ->
                tuple("${sampleName}_${fractions[0].fractionId}", fractions[0].fractionId,
                    idxml, fractions[0].mzml)
            }
        split_idXML(sampleRecords.filter { sampleName, idxml, fractions -> fractions.size() > 1 })
        splitFractions = split_idXML.out.split.flatMap { sampleName, fractions, splitFiles ->
            matchFractions(sampleName, fractions, splitFiles)
        }
        pairedFractions = singleFractions.mix(splitFractions)
    } else {
        pairedFractions = sampleRecords.map { sampleName, idxml, fractions ->
            tuple("${sampleName}_${fractions[0].fractionId}", fractions[0].fractionId,
                idxml, fractions[0].mzml)
        }
    }
    set_EasyPQP_idXML_score(pairedFractions)
    convert_EasyPQP(set_EasyPQP_idXML_score.out.prepared)

    converted = convert_EasyPQP.out.converted.collect(flat: false)
    if (params.fractionated) {
        convertedByFraction = converted.flatMap { rows ->
            def byFraction = rows.groupBy { it[1] }
            byFraction.keySet().sort().collect { fractionId ->
                def ordered = byFraction[fractionId].sort { left, right -> left[0] <=> right[0] }
                tuple(params.dataset_id, fractionId,
                    ordered.collect { it[2] }, ordered.collect { it[3] })
            }
        }
    } else {
        // Unfractionated samples retain the original single cohort library.
        convertedByFraction = converted.map { rows ->
            def ordered = rows.sort { left, right -> left[0] <=> right[0] }
            tuple(params.dataset_id, 'all',
                ordered.collect { it[2] }, ordered.collect { it[3] })
        }
    }

    library_EasyPQP(convertedByFraction, file(params.psm_tsv), file(params.peptide_tsv))

    fractionLibraries = library_EasyPQP.out.library
        .collect(flat: false)
        .map { rows ->
            def ordered = rows.sort { left, right -> left[0] <=> right[0] }
            tuple(params.dataset_id,
                ordered.collect { it[0] }, ordered.collect { it[1] })
        }
    combine_FractionSpectralLibrary(fractionLibraries)
}
