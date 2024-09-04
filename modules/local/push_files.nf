process PUSH_FILES {
    label 'process_low'
    publishDir "${publish_dir}"

    //conda "conda-forge::python=3.8.3"
    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/python:3.8.3' :
    //    'biocontainers/python:3.8.3' }"

    input:
    tuple val(id), val(sample), val(file_name), val(gs_file), val(timestamp), val(workspace), val(workflow)

    output:
    //path gs_file, emit: input_file
    tuple val(id), val(sample), val(file_name), val(gs_file), val("${publish_dir}/${file_name}"), val(timestamp), val("terra"), val(workspace), val(workflow), emit: metadata
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    publish_dir = "${params.outdir}/data/id=${sample}/workflow=${workflow}/file=${file_name}/timestamp=${timestamp}"

    script:
    """
    ls
    """
}
