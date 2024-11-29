/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MAF2VCF                } from '../modules/local/maf2vcf/main'
include { VEP                    } from '../modules/local/vep/main'
include { SETUP_VEP_ENVIRONMENT  } from '../modules/local/vep/vep_env'
include { PVACSEQ_PIPELINE       } from '../modules/local/pvacseq/main'
include { CONFIGURE_PVACSEQ      } from '../modules/local/pvacseq/pvacseq_env'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'

include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_pvacseq_pipeline'
include { CONFIGURE_PVACSEQ_IEDB } from '../subworkflows/local/configure_pvacseq'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/



workflow PVACSEQ {

    take:
    ch_maf_files   // Channel: directory with input files (MAF)
    ch_vcf_files   // Channel: directory with input files (VCF)
    fasta          // Path to reference genome
    hla_csv        // Preprocessed HLA CSV file path

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Process MAF files (if provided)

    //
    // MODULE: Run MAF2VCF
    //
    MAF2VCF (
        ch_maf_files,
        fasta
    )

    ch_vcf_files = ch_vcf_files.mix(MAF2VCF.out.vcf)
    ch_versions = ch_versions.mix(MAF2VCF.out.versions.first())
    
    
    // Check and Install VEP Parameters
    SETUP_VEP_ENVIRONMENT (
        params.vep_cache ?: '',
        params.vep_cache_version ?: '',
        params.vep_plugins ?: '',
        params.outdir
    )
    
    //
    // MODULE: Run VEP
    //
    VEP (
        ch_vcf_files.map { tuple ->
            return tuple[0..1] // Pass only metadata and path to VCF
        },
        fasta,
        SETUP_VEP_ENVIRONMENT.out.vep_cache_version,
        SETUP_VEP_ENVIRONMENT.out.vep_cache,
        SETUP_VEP_ENVIRONMENT.out.vep_plugins
    )

    ch_versions = ch_versions.mix(VEP.out.versions.first())

    // Load and Normalize HLA Data
    hla_ch = Channel
        .fromPath(hla_csv)
        .splitCsv(header: true)
        .map { row ->
            // Extract sample ID and raw HLA string
            def sample_id = row.Sample_ID
            def hla_string = row.HLA_Types.replace(';', ',').trim()

            // Normalize HLA string to consistent format
            def normalized_hla = hla_string.split(',')
                .collect { hla -> 
                    hla.trim().replaceAll(/HLA-([A-Z])([0-9]+:[0-9]+)/, 'HLA-$1*$2') 
                }
                .join(',')
            return [sample_id, normalized_hla]
        }


    tumor_pvacseq_ch = VEP.out.vcf
        .join(MAF2VCF.out.vcf)
        .map { tuple ->
            // Extract tumor and normal samples
            def tumor_sample = file(tuple[3]).text.split('\n')[1].split('\t')[0]
            def normal_sample = file(tuple[3]).text.split('\n')[1].split('\t')[1]
            // Extract tumor and normal sample from files and add them
            return [tumor_sample, normal_sample, tuple[0], tuple[1], tuple[3]]
        }
    
    // Reorder just so that normal sample is a key now
    normal_pvacseq_ch = tumor_pvacseq_ch
        .map { tuple ->
            return [tuple[1], tuple[0], tuple[2], tuple[3], tuple[4]]
        }

    // Merge HLA info in case we have tumor sample id
    tumor_pvacseq_ch = tumor_pvacseq_ch
        .join(hla_ch).map { tuple ->
            // Reorder for PVACSEQ_PIPELINE process
            return [tuple[2], tuple[3], tuple[4], tuple[5], tuple[0], tuple[1]]
        }
    
    // Merge HLA info in case we have normal sample id
    normal_pvacseq_ch = normal_pvacseq_ch
        .join(hla_ch).map { tuple ->
            // Reorder for PVACSEQ_PIPELINE process
            return [tuple[2], tuple[3], tuple[4], tuple[5], tuple[1], tuple[0]]
        }

    pvacseq_ch = tumor_pvacseq_ch.mix(normal_pvacseq_ch)


    // Download mhc_i and mhc_ii iedb if required
    CONFIGURE_PVACSEQ_IEDB (
        params.pvacseq_iedb ?: '',
        params.pvacseq_algorithm ?: ''
    )
    
    // Configure pvacseq before running it
    CONFIGURE_PVACSEQ (
        CONFIGURE_PVACSEQ_IEDB.out.iedb_mhc_i,
        CONFIGURE_PVACSEQ_IEDB.out.iedb_mhc_ii
    )

    //
    // MODULE: Run pVAcseq tool
    //
    PVACSEQ_PIPELINE (
        pvacseq_ch,
        fasta,
        params.pvacseq_algorithm,
        params.pvacseq_peptide_length_i,
        params.pvacseq_peptide_length_ii,
        CONFIGURE_PVACSEQ_IEDB.out.iedb_dir,
        CONFIGURE_PVACSEQ.out.config_file,
        params.pvacseq_advanced_options
    )

    ch_multiqc_files = ch_multiqc_files.mix(PVACSEQ_PIPELINE.out.mhc_i_out.collect { it[1] })
    ch_multiqc_files = ch_multiqc_files.mix(PVACSEQ_PIPELINE.out.mhc_ii_out.collect { it[1] })
    ch_versions = ch_versions.mix(PVACSEQ_PIPELINE.out.versions.first())


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
