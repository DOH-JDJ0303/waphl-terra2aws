process CMP_TABLES {
    label 'process_low'

    //conda "conda-forge::python=3.8.3"
    //container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/python:3.8.3' :
    //    'biocontainers/python:3.8.3' }"

    input:
    tuple val(terra_project), val(terra_workspace), path(new_tables, stageAs: "new/*"), path(old_tables, stageAs: "old")

    output:
    tuple val(terra_project), val(terra_workspace), path('delta/*'), emit: tables
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    mkdir delta
    for t in \$(ls new/)
    do
        if [ -f old/\${t} ]
        then
            if [[ 0 < \$(comm -3 <(cat new/\${t} | sort) <(cat old/\${t} | sort) | wc -l) ]]
            then
                mv new/\${t} delta/\${t}
            fi
        else
            mv new/\${t} delta/\${t}
        fi 
    done
    """
}
