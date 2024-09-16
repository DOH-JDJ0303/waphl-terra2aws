process PUSH_META {
    label 'process_low'
    publishDir "${publish_dir}"

    input:
    path metadata

    output:
    path metadata, optional: true
    env wait_var, emit: wait
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    wait_var="wait for me!"
    # remove metadata file if it only contains column line - avoids pushing empty tables
    if [[ \$( cat ${metadata} | wc -l ) == 1 ]]
    then
        rm ${metadata}
    fi
    """
}
