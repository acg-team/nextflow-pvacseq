/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MAF2VCF                } from '../modules/local/maf2vcf/main'
include { VEP                    } from '../modules/local/vep/main'
include { SETUP_VEP_ENVIRONMENT  } from '../modules/local/vep/vep_env'
include { PVACSEQ_PIPELINE       } from '../modules/local/pvacseq/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_pvacseq_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/



workflow PVACSEQ {

    take:
    ch_maf_files // channel: directory with maf files read in from --input
    fasta        // path to reference genome

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()


    //
    // PROCESS: Check and Install VEP Parameters
    //
    SETUP_VEP_ENVIRONMENT (
        params.vep_cache,
        params.vep_cahce_vesrion,
        params.vep_plugins,
        params.outdir
    )
    
    //
    // MODULE: Run maf2vcf
    //
    MAF2VCF (
        ch_maf_files,
        fasta
    )

    ch_versions = ch_versions.mix(MAF2VCF.out.versions.first())
    
    //
    // MODULE: Run VEP
    //
    VEP (
        MAF2VCF.out.vcf.map { tuple ->
            return tuple[0..1]
        },
        fasta,
        SETUP_VEP_ENVIRONMENT.out.vep_cache_version,
        SETUP_VEP_ENVIRONMENT.out.vep_cache,
        SETUP_VEP_ENVIRONMENT.out.vep_plugins
    )

    ch_versions = ch_versions.mix(VEP.out.versions.first())

    pvacseq_ch = VEP.out.vcf.join(MAF2VCF.out.vcf).map { tuple ->
        // Extract tumor sample from pairs.tsv file
        def tumor_sample = file(tuple[3]).text.split('\n')[1].split('\t')[0]
        def normal_sample = file(tuple[3]).text.split('\n')[1].split('\t')[1]
        // Construct path to the HLA file
        def hla_file_path = "${params.hla_directory}/${tumor_sample}/hla_types.txt"
        def hla_content = ""

        if (file("${params.hla_directory}/${tumor_sample}/hla_types.txt").exists()) {
            hla_content = file("${params.hla_directory}/${tumor_sample}/hla_types.txt").text.replaceAll('\n', '')
        } else {
            if (file("${params.hla_directory}/${normal_sample}/hla_types.txt").exists()) {
                hla_content = file("${params.hla_directory}/${normal_sample}/hla_types.txt").text.replaceAll('\n', '')
            } else {
                // Log a message if HLA file does not exist
                println "Warning: HLA file not found with tumor sample ${tumor_sample}; normal sample ${normal_sample}"
            }
        }
        
        def hla = hla_content.replaceAll(/HLA-([A-Z])([0-9]*:[0-9]*)/, 'HLA-$1*$2').trim()
        // Return tuple with the additional HLA file path
        // Remove MAF2VCF vcf file
        return [tuple[0], tuple[1], tuple[3]] + [hla, tumor_sample, normal_sample]
    }

    //
    // MODULE: Run pVAcseq tool
    //
    PVACSEQ_PIPELINE (
        pvacseq_ch,
        fasta,
        params.pvacseq_algorithm,
        params.pvacseq_peptide_length_i,
        params.pvacseq_peptide_length_ii,
        params.pvacseq_iedb
    )

    ch_multiqc_files = ch_multiqc_files.mix(PVACSEQ_PIPELINE.out.mhc_i_out.collect{it[1]})


    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
