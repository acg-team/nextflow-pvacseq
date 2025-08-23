process SMART_LINK_IEDB {
    tag "smart_link_iedb"
    label 'process_single'

    input:
    path iedb_source

    output:
    stdout emit: iedb_stdout

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    smart_link_iedb.py --src "${iedb_source}"
    """
}
