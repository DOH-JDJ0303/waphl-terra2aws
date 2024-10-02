process PUSH_FILES {
    label 'process_low'

    input:
    tuple path(meta), path(google_cred_json)

    output:
    path "**/*", emit: files, optional: true
    path "meta_*", emit: meta
    //path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    gcred_cmd = file(google_cred_json).getExtension() == "gz" ? "tar -xzf ${google_cred_json} -C ~/.config/gcloud/" : "mv ${google_cred_json} ~/.config/gcloud"

    script:
    """
    # set google credentials
    mkdir -p ~/.config/gcloud/ || true
    ${gcred_cmd}

    # prepare metadata header
    echo "ID,ALT_ID,FILE,ORIGIN_PATH,CURRENT_PATH,TIMESTAMP,PLATFORM,WORKSPACE,WORKFLOW" > meta_${params.run_time}.csv

    # download files
    for LINE in \$(cat ${meta})
    do
        LINE=\$(echo \$LINE | tr -d '\t\r\n ')
        # extract info
        GS_PATH=\$(echo \$LINE | cut -f 4 -d ',')
        NEW_PATH=\$(echo \$LINE | awk -v FS=',' '{print "data/id="\$1"/workflow="\$7"/file="\$3"/timestamp="\$5}')
        FILE_NAME=\$(echo \$LINE | cut -f 3 -d ',')

        # copy files
        mkdir -p \${NEW_PATH}
        gsutil cp \${GS_PATH} \${NEW_PATH} || NEW_PATH="ERROR_File_not_found"

        # export updated metadata
        echo \$LINE | awk -v FS=',' -v OFS=',' -v newpath="${params.outdir}\${NEW_PATH}" '{print \$1,\$2,\$3,\$4,newpath,\$5,"Terra",\$6,\$7}' >> meta_${params.run_time}.csv
    done
    """
}


