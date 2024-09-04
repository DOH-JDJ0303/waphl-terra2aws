process EXTRACT_ID {
    label 'process_low'

    //conda "conda-forge::python=3.8.3"
    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/python:3.8.3' :
    //    'biocontainers/python:3.8.3' }"

    input:
    tuple val(name), val(patterns)

    output:
    tuple val(name), env(id), emit: ids
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    extract_ids.py -i "${name}" --patterns ${patterns}
    id=\$(cat ids.csv)
    """
}
