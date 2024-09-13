process PUSH_TABLES {
    label 'process_low'
    publishDir "${publish_dir}"

    input:
    tuple val(project), val(workspace), path(table), val(metadata)

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
