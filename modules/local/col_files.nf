process COL_FILES {
    label 'process_low'

    input:
    tuple val(terra_project), val(terra_workspace), path(table)

    output:
    tuple val(terra_project), val(terra_workspace), path("*.csv"), emit: files
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    col_files.sh ${table}
    """
}
