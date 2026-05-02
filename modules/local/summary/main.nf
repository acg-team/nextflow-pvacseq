process PVACSEQ_SUMMARY {
    tag "pvacseq_summary"
    label 'process_single'

    conda "${moduleDir}/environment.yml"

    input:
    path filtered_files
    val  sample_names

    output:
    path "figures/*.png",          emit: figures
    path "summary_plots_mqc.yaml", emit: multiqc_files

    when:
    task.ext.when == null || task.ext.when

    script:
    def files_arg = (filtered_files instanceof List ? filtered_files : [filtered_files]).join(' ')
    def names_arg = (sample_names instanceof List ? sample_names : [sample_names]).join(' ')
    """
    python3 ${moduleDir}/plots.py \\
        --filtered-files ${files_arg} \\
        --sample-names ${names_arg} \\
        --out-dir figures
    """
}
