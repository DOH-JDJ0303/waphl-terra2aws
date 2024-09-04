workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:

    Channel.fromPath( samplesheet )
        .splitCsv ( header:true, sep:',' )
        .map { check_input(it) }
        .set { manifest }

    emit:
    manifest
}

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def check_input(LinkedHashMap row) {
    terra_project       = row.terra_project       ? row.terra_project                      : null
    terra_workspace     = row.terra_workspace     ? row.terra_workspace                    : null
    terra_workflow_name = row.terra_workflow_name ? row.terra_workflow_name                : null
    dest_workflow_name  = row.dest_workflow_name  ? row.dest_workflow_name                 : terra_workflow_name
    sample_patterns     = row.sample_patterns     ? row.sample_patterns                    : '*'

    if (!(terra_project && terra_workspace && terra_workflow_name)){
        exit 1, "ERROR: One of the following sample fields are missing:\nterra_project:${terra_project}\nterra_workspace: ${terra_workspace}\nterra_workflow_name: ${terra_workflow_name}\ndest_workflow_name: ${dest_workflow_name}\ndest_path: ${dest_path}"
    }

    samplesheet = [ terra_project: terra_project, 
                    terra_workspace: terra_workspace, 
                    terra_workflow_name: terra_workflow_name, 
                    dest_workflow_name: dest_workflow_name,
                    sample_patterns: sample_patterns ]

}