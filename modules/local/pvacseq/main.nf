// TODO
// 1. Validate hla string and add different types of hla string support
// 2. Validate input

// Works only for MHC_Class_I
process PVACSEQ_PIPELINE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(vcf), path(pairs), val(hla), val(tumor_sample), val(normal_sample)
    path  fasta
    val algorithm
    val peptide_length_i 
    val peptide_length_ii 
    path iedb // path to iedb-install-directory 

    output:
    // tuple val(meta), path("${tumor_sample}/MHC_Class_I/${tumor_sample}.filtered.tsv")     , emit: neoantigens
    tuple val(meta), path("${tumor_sample}/MHC_Class_I/${tumor_sample}.filtered.tsv"), path("${tumor_sample}/MHC_Class_I/${tumor_sample}.all_epitopes.tsv"), optional: true, emit: mhc_i_out
    tuple val(meta), path("${tumor_sample}/MHC_Class_II/${tumor_sample}.filtered.tsv"), path("${tumor_sample}/MHC_Class_II/${tumor_sample}.all_epitopes.tsv"), optional: true, emit: mhc_ii_out
    path "versions.yml"                                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def e1 = peptide_length_i ?: "9" // If peptide_length_i is null, default to "9"
    def e2 = peptide_length_ii ?: "15" // If peptide_length_ii is null, default to "15"

    assert hla && tumor_sample && normal_sample : "hla, tumor_sample, and normal_sample must not be empty"
    // Validate HLA format
    // assert hla.matches(/^(HLA-)?[A-Z]\*\d{2}:\d{2}$/) : "HLA format is not valid: ${hla}"

    // Validate each HLA string
    hla.split(',').each { hla_string ->
        assert hla_string.matches(/^(HLA-)?[A-Z]\*\d{2}:\d{2}$/) : "HLA format is not valid: ${hla_string}"
    }
    """
    pvacseq run \\
        $vcf \\
        $tumor_sample \\
        $hla \\
        $algorithm \\
        $tumor_sample/ \\
        -e1 $e1 -e2 $e2 \\
        --normal-sample-name $normal_sample \\
        --iedb-install-directory $iedb \\
        -t $task.cpus


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pvactools: echo \$(pvactools -v 2>&1) 
    END_VERSIONS
    """
}