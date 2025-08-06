#!/usr/bin/env nextflow

nextflow.enable.dsl = 2


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PVACSEQ_PIPELINE        } from './workflows/pvacseq'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_pvacseq_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_pvacseq_pipeline'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_PVACSEQ {

    take:
    maf_files // channel: directory with maf files read in from --input
    vcf_files // channel: directory with vcf files read in from --input
    main:

    //
    // WORKFLOW: Run pipeline
    //
    PVACSEQ_PIPELINE (
        maf_files,
        vcf_files,
        params.fasta,
        params.hla_csv
    )

    emit:
    multiqc_report = PVACSEQ_PIPELINE.out.multiqc_report // channel: /path/to/multiqc_report.html

}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.help,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )


    //
    // Generate input channels dynamically for MAF and VCF files
    //
    ch_maf_files = Channel
        .fromPath(params.input + "/*.maf")
        .map { file ->
            [ [id: file.baseName], file ] // Create tuples with metadata (id) and file path
        }

    ch_vcf_files = Channel
        .fromPath(params.input + "/*.vcf")
        .map { file ->
            [ [id: file.baseName], file ] // Create tuples with metadata (id) and file path
        }

    //
    // Combine MAF and VCF channels into one
    //
    ch_input_files = ch_maf_files.mix(ch_vcf_files)

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_PVACSEQ (
        ch_maf_files,
        ch_vcf_files
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_PVACSEQ.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
