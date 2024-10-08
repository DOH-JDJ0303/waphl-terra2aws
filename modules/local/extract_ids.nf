process EXTRACT_ID {
    label 'process_low'

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
