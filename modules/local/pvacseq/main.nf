process PVACSEQ_PIPELINE {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "docker.io/griffithlab/pvactools:5.3.1"
    
    input:
    tuple val(meta), path(vcf), val(hla), val(tumor_sample), val(normal_sample)
    val algorithms
    path iedb // path to iedb-install-directory 
    // path 'env_config_done.txt' // path to config 
    val options // map of additional pVACseq options

    output:
        // Emit all relevant pVACseq files from both MHC classes
        // A list of filtered epitopes
        path("${tumor_sample}/MHC_Class_I/${tumor_sample}.filtered.tsv") , emit: mhc_i_filtered   , optional: true
        path("${tumor_sample}/MHC_Class_II/${tumor_sample}.filtered.tsv"), emit: mhc_ii_filtered  , optional: true
        path("${tumor_sample}/combined/${tumor_sample}.filtered.tsv")    , emit: combined_filtered, optional: true

        // A list of all predicted epitopes
        path("${tumor_sample}/MHC_Class_I/${tumor_sample}.all_epitopes.tsv") , emit: mhc_i_all   , optional: true
        path("${tumor_sample}/MHC_Class_II/${tumor_sample}.all_epitopes.tsv"), emit: mhc_ii_all  , optional: true
        path("${tumor_sample}/combined/${tumor_sample}.all_epitopes.tsv")    , emit: combined_all, optional: true

        // Folder with all outputs
        path("${tumor_sample}/MHC_Class_I"), emit: mhc_i_dir, optional: true
        path("${tumor_sample}/MHC_Class_II"), emit: mhc_ii_dir, optional: true
        path("${tumor_sample}/combined"), emit: combined_dir, optional: true

        // Emit version tracking
        path "versions.yml", emit: versions


    when:
    // Execute the task unless explicitly told not to
    task.ext.when == null || task.ext.when

    script:
    //def e1 = peptide_length_i ?: "9" // If peptide_length_i is null, default to "9"
    //def e2 = peptide_length_ii ?: "15" // If peptide_length_ii is null, default to "15"

   
    assert hla && tumor_sample && normal_sample : "hla, tumor_sample, and normal_sample must not be empty"
    
    
    // Validate each HLA string
    hla.split(',').each { hla_string ->
        if(!hla_string.matches(/^(HLA-)?[A-Z]\*\d{2}:\d{2}$/)) 
            println "${meta.id} WARNING: HLA format is not valid: ${hla_string}"
    }

    // Define which keys should use a single dash
    def singleDashOptions = ['r', 't', 'e1', 'e2', 'b', 'm', 'p', 'c', 'd', 's', 'a']

    // Build additional options dynamically
    def additional_options = options.collect { key, value ->
        def prefix = singleDashOptions.contains(key) ? '-' : '--'

        if (value == null) {
            "" // Skip nulls
        } else if (value instanceof Boolean) {
            value ? "${prefix}${key}" : "" // Include flag only if true
        } else {
            "${prefix}${key} ${value}" // Include option with value
        }
    }.findAll { it }.join(' ')




    // Execute pvacseq command with provided parameters
    """
    pvacseq run \\
        $vcf \\
        $tumor_sample \\
        $hla \\
        $algorithms \\
        $tumor_sample/ \\
        --iedb-install-directory $iedb \\
        --normal-sample-name $normal_sample \\
        -t $task.cpus \\
        $additional_options


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PVACSEQ: echo \$(pvactools -v 2>&1) 
    END_VERSIONS
    """
}