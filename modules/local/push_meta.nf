process PUSH_META {
    label 'process_low'
    publishDir "${publish_dir}"

    input:
    path metadata

    output:
    path metadata
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    ls
    """
}
