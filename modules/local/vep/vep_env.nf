// Process to check and install VEP parameters if not provided
process SETUP_VEP_ENVIRONMENT {

    // Input parameters
    input:
    // Params containing VEP parameters
    val vep_cache
    val vep_cache_version
    val vep_plugins
    val outdir // Outdir to put downloaded folders

    // Output: Paths to downloaded files
    output:
    path "vep_cache",      emit: vep_cache
    path "vep_plugins",    emit: vep_plugins
    val vep_cache_version, emit: vep_cache_version
    path "versions.yml",   emit: versions
    // Script section
    script:

    // First block: Handle all checks and messages

    // We cant have no version, but if vep_cache is provided we can't download the new one eather 
    if (vep_cache && !vep_cache_version) {
        throw new Exception("VEP cache provided but version not indicated. Please provide 'vep_cache_version'.")
    }


    vep_cache_version = vep_cache_version ?: '102'
    println "VEP cache version is $vep_cache_version"

    // Check VEP cache directory
    if (!(vep_cache && file(vep_cache).exists())) {
        if (!file("${outdir}/vep_cache_${vep_cache_version}").exists()) {
            println "VEP cache directory not found. Will download and extract."
        } else {
            println "${outdir}/vep_cache_${vep_cache_version} already exists. Please specify it via the 'vep_cache' parameter or --vep_cache."
            throw new Exception("VEP cache directory already exists at ${outdir}/vep_cache_${vep_cache_version} but not indicated.")
        }
    } else {
        println "VEP cache found at $vep_cache"
    }

    // Check VEP plugins directory
    if (!(vep_plugins && file(vep_plugins).exists())) {
        if (!file("${outdir}/VEP_plugins").exists()) {
            println "VEP plugins directory not found. Will clone from GitHub."
        } else {
            println "${outdir}/VEP_plugins already exists. Please specify it via the 'vep_plugins' parameter or --vep_plugins."
            throw new Exception("VEP plugins directory already exists at ${outdir}/VEP_plugins but not indicated.")
        }
    } else {
        println "VEP plugins found at $vep_plugins"
    }

    // Second block: Execute the actual work (downloading, extracting, linking)
    """
    if [[ ! -d "$vep_cache" ]]; then
        mkdir -p "${outdir}/vep_cache_${vep_cache_version}"
        curl -O "https://ftp.ensembl.org/pub/release-${vep_cache_version}/variation/indexed_vep_cache/homo_sapiens_vep_${vep_cache_version}_GRCh38.tar.gz"
        tar xzf "homo_sapiens_vep_${vep_cache_version}_GRCh38.tar.gz" -C "${outdir}/vep_cache_${vep_cache_version}"
        rm "homo_sapiens_vep_${vep_cache_version}_GRCh38.tar.gz"
        ln -s "${outdir}/vep_cache_${vep_cache_version}" vep_cache

    else
        ln -s "$vep_cache" vep_cache

    fi

    if [[ ! -d "$vep_plugins" ]]; then
        mkdir -p "${outdir}/VEP_plugins"
        git clone https://github.com/Ensembl/VEP_plugins.git "${outdir}/VEP_plugins"
        ln -s "${outdir}/VEP_plugins" vep_plugins
        
    else
        ln -s "$vep_plugins" vep_plugins

    fi
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        VEP version: $vep_cache_version
    END_VERSIONS
    """
}
