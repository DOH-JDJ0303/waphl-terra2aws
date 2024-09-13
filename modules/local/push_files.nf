process PUSH_FILES {
    label 'process_low'

    input:
    tuple val(id), val(sample), val(file_name), val(gs_name), val(timestamp), val(workspace), val(workflow), path(google_cred_json)

    output:
    tuple val(id), val(sample), val(file_name), val(gs_name), path("${file_name}"), val("${publish_dir}/${file_name}"), val(timestamp), val("Terra"), val(workspace), val(workflow), emit: metadata
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    publish_dir="${params.outdir}/data/id=${sample}/workflow=${workflow}/file=${file_name}/timestamp=${timestamp}"
    gcred_cmd = file(google_cred_json).getExtension() == "gz" ? "tar -xzf ${google_cred_json} -C ~/.config/gcloud/" : "mv ${google_cred_json} ~/.config/gcloud"

    script:
    """
    # set google credentials
    mkdir -p ~/.config/gcloud/ || true
    ${gcred_cmd}

    gsutil cp ${gs_name} ./
    """
}
