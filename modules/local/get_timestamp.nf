process GET_TIMESTAMP {
    label 'process_single'

    input:
    tuple val(gs_file), path(google_cred_json)

    output:
    path "timestamp.csv", emit: timestamp
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    gcred_cmd = file(google_cred_json).getExtension() == "gz" ? "tar -xzf ${google_cred_json} -C ~/.config/gcloud/" : "mv ${google_cred_json} ~/.config/gcloud"

    script:
    """
    # set google credentials
    mkdir -p ~/.config/gcloud/ || true
    ${gcred_cmd}

    google_project=\$(cat ~/.config/gcloud/application_default_credentials.json | grep quota_project_id | sed 's/.*: //g' | tr -d '\n\r\t ",')

    # get list of tables
    get_timestamp.py -i ${gs_file} -p \${google_project} || echo "${gs_file},ERROR: File not found in GCP" > timestamp.csv
    """
}
