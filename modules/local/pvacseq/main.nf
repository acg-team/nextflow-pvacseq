process PVACSEQ_PIPELINE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "docker.io/griffithlab/pvactools:4.0.7"
    
    input:
    tuple val(meta), path(vcf), path(pairs), val(hla), val(tumor_sample), val(normal_sample)
    path  fasta
    val algorithm
    val peptide_length_i 
    val peptide_length_ii 
    path iedb // path to iedb-install-directory 
    path 'env_config_done.txt' // path to config 

    output:
    // Output tuple for MHC Class I 
    tuple val(meta), path("${tumor_sample}/MHC_Class_I/${tumor_sample}.filtered.tsv"), path("${tumor_sample}/MHC_Class_I/${tumor_sample}.all_epitopes.tsv"), optional: true, emit: mhc_i_out
    // Output tuple for MHC Class II 
    tuple val(meta), path("${tumor_sample}/MHC_Class_II/${tumor_sample}.filtered.tsv"), path("${tumor_sample}/MHC_Class_II/${tumor_sample}.all_epitopes.tsv"), optional: true, emit: mhc_ii_out
    path "versions.yml"                                       , emit: versions

    when:
    // Execute the task unless explicitly told not to
    task.ext.when == null || task.ext.when

    script:
    def e1 = peptide_length_i ?: "9" // If peptide_length_i is null, default to "9"
    def e2 = peptide_length_ii ?: "15" // If peptide_length_ii is null, default to "15"

   
    assert hla && tumor_sample && normal_sample : "hla, tumor_sample, and normal_sample must not be empty"
    
    
    // Validate each HLA string
    hla.split(',').each { hla_string ->
        if(!hla_string.matches(/^(HLA-)?[A-Z]\*\d{2}:\d{2}$/)) 
            println "${meta.id} WARNING: HLA format is not valid: ${hla_string}"
    }

    // Execute pvacseq command with provided parameters
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
        PVACSEQ: echo \$(pvactools -v 2>&1) 
    END_VERSIONS
    """
}