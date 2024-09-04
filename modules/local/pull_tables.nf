process PULL_TABLES {
    label 'process_low'

    //conda "conda-forge::python=3.8.3"
    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/python:3.8.3' :
    //    'biocontainers/python:3.8.3' }"

    input:
    tuple val(terra_project), val(terra_workspace)

    output:
    tuple val(terra_project), val(terra_workspace), path('*.tsv'), emit: tables
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # get list of tables
    pull_tables.py -p "${terra_project}" -w "${terra_workspace}"
    # download tables
    for t in \$(cat tables.csv)
    do
        export_large_tsv.py -p "${terra_project}" -w "${terra_workspace}" -e \${t} -f \${t}.tsv
    done    
    """
}
