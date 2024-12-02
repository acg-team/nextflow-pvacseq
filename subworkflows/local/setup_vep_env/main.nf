//
// Process: Download VEP Cache
//
process DOWNLOAD_VEP_CACHE {
    input:
    val cache_version
    path outdir

    output:
    path "${outdir}/vep_cache_${cache_version}", emit: vep_cache_out

    script:
    """
    mkdir -p "${outdir}/vep_cache_${cache_version}"
    curl -O "https://ftp.ensembl.org/pub/release-${cache_version}/variation/indexed_vep_cache/homo_sapiens_vep_${cache_version}_GRCh38.tar.gz"
    tar xzf "homo_sapiens_vep_${cache_version}_GRCh38.tar.gz" -C "${outdir}/vep_cache_${cache_version}"
    rm "homo_sapiens_vep_${cache_version}_GRCh38.tar.gz"
    """
}

//
// Process: Download VEP Plugins
//
process DOWNLOAD_VEP_PLUGINS {
    input:
    path outdir

    output:
    path "${outdir}/VEP_plugins", emit: vep_plugins_out

    script:
    """
    mkdir -p "${outdir}/VEP_plugins"
    git clone https://github.com/Ensembl/VEP_plugins.git "${outdir}/VEP_plugins"
    wget "https://github.com/griffithlab/pVACtools/archive/refs/tags/v4.0.7.zip"
    unzip v4.0.7.zip "pVACtools-4.0.7/pvactools/tools/pvacseq/VEP_plugins/*"
    mv pVACtools-4.0.7/pvactools/tools/pvacseq/VEP_plugins/* "${outdir}/VEP_plugins/"
    rm -rf pVACtools-4.0.7
    rm v4.0.7.zip
    """
}


workflow SETUP_VEP_ENVIRONMENT {
    take:
    vep_cache
    vep_cache_version
    vep_plugins
    outdir // Outdir to put downloaded folders

    main:
    // We cant have no version, but if vep_cache is provided we can't download the new one eather 
    if (vep_cache && !vep_cache_version) {
        throw new Exception("VEP cache provided but version not indicated. Please provide 'vep_cache_version'.")
    }

    vep_cache_version = vep_cache_version ?: '102'
    println "Using VEP cache version: $vep_cache_version"

    // Check VEP cache directory
    if (!(vep_cache && file(vep_cache).exists())) {
        if (!file("${outdir}/vep_cache_${vep_cache_version}").exists()) {
            println "VEP cache directory not found. Will download and extract."
            DOWNLOAD_VEP_CACHE(vep_cache_version, outdir)
            cache_dir = DOWNLOAD_VEP_CACHE.out.vep_cache_out
        } else {
            println "${outdir}/vep_cache_${vep_cache_version} already exists. Please specify it via the 'vep_cache' parameter or --vep_cache."
            throw new Exception("VEP cache directory already exists at ${outdir}/vep_cache_${vep_cache_version} but not indicated.")
        }
    } else {
        println "VEP cache found at $vep_cache"
        cache_dir = file("$vep_cache")
    }

    // Check VEP plugins directory
    if (!(vep_plugins && file(vep_plugins).exists())) {
        if (!file("${outdir}/VEP_plugins").exists()) {
            println "VEP plugins directory not found. Will clone from GitHub."
            DOWNLOAD_VEP_PLUGINS(outdir)
            plugins_dir = DOWNLOAD_VEP_PLUGINS.out.vep_plugins_out
        } else {
            println "${outdir}/VEP_plugins already exists. Please specify it via the 'vep_plugins' parameter or --vep_plugins."
            throw new Exception("VEP plugins directory already exists at ${outdir}/VEP_plugins but not indicated.")
        }
    } else {
        println "VEP plugins found at $vep_plugins"
        plugins_dir = file("$vep_plugins")
    }

    emit:
    vep_cache = cache_dir
    vep_plugins = plugins_dir
    vep_cache_version = vep_cache_version
}
