process PULL_TABLES {
    label 'process_low'

    input:
    tuple val(terra_project), val(terra_workspace), path(google_cred_json)

    output:
    tuple val(terra_project), val(terra_workspace), path('*.tsv'), emit: tables
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    gcred_cmd = file(google_cred_json).getExtension() == "gz" ? "tar -xzvf ${google_cred_json} -C ~/.config/gcloud/" : "mv ${google_cred_json} ~/.config/gcloud"

    script:
    """
    # set google credentials
    mkdir -p ~/.config/gcloud/ || true
    ${gcred_cmd}

    # get list of tables
    pull_tables.py -p "${terra_project}" -w "${terra_workspace}"
    # download tables
    for t in \$(cat tables.csv)
    do
        export_large_tsv.py -p "${terra_project}" -w "${terra_workspace}" -e \${t} -f \${t}.tsv
    done    
    """
}
