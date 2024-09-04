process COL_FILES {
    label 'process_low'

    //conda "conda-forge::python=3.8.3"
    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/python:3.8.3' :
    //    'biocontainers/python:3.8.3' }"

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
