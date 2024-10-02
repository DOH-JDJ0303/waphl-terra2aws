process PUSH_TABLES {
    label 'process_low'

    input:
    tuple val(project), val(workspace), path(table)

    output:
    path table
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    ls
    """
}
