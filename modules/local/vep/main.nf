// Based on nf-core module ensemblvep_vep https://nf-co.re/modules/ensemblvep_vep
// Modified for pVACseq tools
process VEP {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ensembl-vep:111.0--pl5321h2a3209d_0' :
        'biocontainers/ensembl-vep:111.0--pl5321h2a3209d_0' }"

    input:
    tuple val(meta), path(vcf)
    path  fasta
    val   cache_version
    path  cache
    path  vep_plugins // required

    output:
    tuple val(meta), path("*_annotated.vcf")     , emit: vcf
    path "*.summary.html"                        , optional:true, emit: report
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = vcf.baseName.split("\\.")[0]
    def dir_cache = cache ? "\${PWD}/${cache}" : "/.vep"
    """
    vep \\
        -i $vcf \\
        -o ${prefix}_annotated.vcf \\
        --fork $task.cpus \\
        --offline \\
        --cache \\
        --cache_version $cache_version \\
        --dir $dir_cache \\
        --dir_cache $dir_cache \\
        --hgvs \\
        --fasta $fasta \\
        --dir_plugins $vep_plugins \\
        --plugin Frameshift --plugin Wildtype \\
        --symbol --terms SO --transcript_version --tsl \\
        --format vcf \\
        --vcf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ensemblvep: \$( echo \$(vep --help 2>&1) | sed 's/^.*Versions:.*ensembl-vep : //;s/ .*\$//')
    END_VERSIONS
    """
}