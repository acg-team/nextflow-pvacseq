//
// MODULE: Download MHC Class I data
//
process DOWNLOAD_MHC_I {
    input:
    path pvacseq_iedb_dir

    output:
    path "$pvacseq_iedb_dir/mhc_i", emit: iedb_mhc_i

    script:
    """
    wget https://downloads.iedb.org/tools/mhci/3.1.5/IEDB_MHC_I-3.1.5.tar.gz
    tar -zxvf IEDB_MHC_I-3.1.5.tar.gz
    mv mhc_i $pvacseq_iedb_dir/mhc_i
    rm -rf IEDB_MHC_I-3.1.5.tar.gz
    """
}

//
// MODULE: Download MHC Class II data
//
process DOWNLOAD_MHC_II {
    input:
    path pvacseq_iedb_dir

    output:
    path "$pvacseq_iedb_dir/mhc_ii", emit: iedb_mhc_ii

    script:
    """
    wget https://downloads.iedb.org/tools/mhcii/3.1.11/IEDB_MHC_II-3.1.11.tar.gz
    tar -zxvf IEDB_MHC_II-3.1.11.tar.gz
    mv mhc_ii $pvacseq_iedb_dir/mhc_ii
    rm -rf IEDB_MHC_II-3.1.11.tar.gz
    """
}


//
// Workflow: Configure pVACseq tools
//
workflow CONFIGURE_PVACSEQ_IEDB {
    take:
    pvacseq_iedb_dir         // directory with IEDB for pVACseq
    pvacseq_algorithm        // string: algorithms for pVACseq 

    main:

    def valid_mhc_i_algorithms = [
        'BigMHC_EL', 'BigMHC_IM', 'DeepImmuno', 'MHCflurry', 'MHCflurryEL',
        'MHCnuggetsI', 'NNalign', 'NetMHC', 'NetMHCpan', 'NetMHCpanEL',
        'PickPocket', 'SMM', 'SMMPMBEC', 'SMMalign', 'all', 'all_class_i'
    ]

    def valid_mhc_ii_algorithms = [
        'MHCnuggetsII', 'NetMHCIIpan', 'NetMHCIIpanEL', 'NetMHCcons',
        'all', 'all_class_ii'
    ]

    def requires_mhc_i = false
    def requires_mhc_ii = false

    // Determine which MHC classes are required
    pvacseq_algorithm.split(' ').each { algorithm ->
        if (valid_mhc_i_algorithms.contains(algorithm)) {
            requires_mhc_i = true
        }
        if (valid_mhc_ii_algorithms.contains(algorithm)) {
            requires_mhc_ii = true
        }
    }

    // If we dont have any requirements, the algorithm string is wrong
    if (!requires_mhc_i && !requires_mhc_ii) {
        throw new IllegalArgumentException("Invalid algorithm string: '${pvacseq_algorithm}'. It must match at least one valid MHC class I or II algorithm.")
    }

    // Create iedb directory if needed
    if (!(pvacseq_iedb_dir && file(pvacseq_iedb_dir).exists())) {
        iedb_dir = file('iedb')
        iedb_dir.mkdir()
    } else {
        iedb_dir = file("$pvacseq_iedb_dir")
    }
    println "IEDB folder will be $iedb_dir"

    // Initialize iedb_ch channel
    iedb_ch = Channel.empty()

    // Add existing paths to iedb_ch
    if (file("$iedb_dir/mhc_i").exists()) {
        println "MHC Class I directory exists at $iedb_dir/mhc_i"
        iedb_ch = iedb_ch.mix(Channel.fromPath("$iedb_dir/mhc_i"))
    }

    if (file("$iedb_dir/mhc_ii").exists()) {
        println "MHC Class II directory exists at $iedb_dir/mhc_ii"
        iedb_ch = iedb_ch.mix(Channel.fromPath("$iedb_dir/mhc_ii"))
    }

    // Download MHC I if required and not already present
    if (requires_mhc_i && !file("$iedb_dir/mhc_i").exists()) {
        println "MHC Class I is required but does not exist. Downloading..."
        DOWNLOAD_MHC_I(iedb_dir)
        iedb_ch = iedb_ch.mix(DOWNLOAD_MHC_I.out.iedb_mhc_i)
    } else if (!requires_mhc_i) {
        println "MHC Class I is not required."
    }

    // Download MHC II if required and not already present
    if (requires_mhc_ii && !file("$iedb_dir/mhc_ii").exists()) {
        println "MHC Class II is required but does not exist. Downloading..."
        DOWNLOAD_MHC_II(iedb_dir)
        iedb_ch = iedb_ch.mix(DOWNLOAD_MHC_II.out.iedb_mhc_ii)
    } else if (!requires_mhc_ii) {
        println "MHC Class II is not required."
    }

    // Reduction is done to synchronize processes and wait for downloads if needed. 
    // We already know iedb path = iedb_dir
    // We assume that iedb_ch have 1 or 2 paths.
    common_iedb_path = iedb_ch.reduce { common_path, next_path ->
        def common_file = file(common_path)
        def next_file = file(next_path)

        // We should have both files in the same folder
        common_file = common_file.getParent()
        assert next_path.startsWith(common_file.toString())

        return common_file.toString()
    }

    assert iedb_dir == common_iedb_path

    emit:
    iedb_ch = iedb_ch
    iedb_dir = common_iedb_path
}
