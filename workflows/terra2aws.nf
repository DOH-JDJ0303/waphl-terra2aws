/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowTerratoaws.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { PULL_TABLES   } from '../modules/local/pull_tables'
include { CMP_TABLES    } from '../modules/local/cmp_tables'
include { COL_FILES     } from '../modules/local/col_files'
include { EXTRACT_ID    } from '../modules/local/extract_ids'
include { GET_TIMESTAMP } from '../modules/local/get_timestamp'
include { PUSH_FILES    } from '../modules/local/push_files'
include { PUSH_META     } from '../modules/local/push_meta'
include { PUSH_TABLES   } from '../modules/local/push_tables'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow TERRA2AWS {

    ch_version = Channel.empty()

    /*
    =============================================================================================================================
        FORMAT SAMPLESHEET INTO CHANNEL
    =============================================================================================================================
    */
    // SUBWORKFLOW: Load samplesheet and format into channel
    INPUT_CHECK ( 
        params.input
    )

    INPUT_CHECK
        .out
        .manifest
        .set{ ch_manifest }

    /*
    =============================================================================================================================
        PULL DOWN TERRA TABLES
    =============================================================================================================================
    */
    // MODULE: Pull all Terra tables from the project workspace
    PULL_TABLES (
        ch_manifest.map{ tuple(it.terra_project, it.terra_workspace, params.google_cred ? params.google_cred : "${workflow.homeDir}/.config/gcloud/") }
    )

    // Determine if tables have been pulled for this workspace before
    PULL_TABLES.out.tables
        .map{ project, workspace, tables -> [ project, workspace, tables, file(params.outdir).resolve("terra_tbls").resolve(project).resolve(workspace).exists() ? file(params.outdir).resolve("terra_tbls").resolve(project).resolve(workspace) : null ] }
        .set{ ch_tables }
        
    ch_tables.filter{ project, workspace, new_tables, old_tables -> !old_tables }.map{ project, workspace, new_tables, old_tables -> [ project, workspace, new_tables ] }.set{ ch_all_new }
    ch_tables.filter{ project, workspace, new_tables, old_tables -> old_tables }.set{ ch_some_new }

    // MODULE: Compare pulled tables to previously pulled tables, returning only those that have changed or are new
    CMP_TABLES (
        ch_some_new
    )

    // Combine all new tables into single channel - limit to --max_tables
    CMP_TABLES.out.tables
        .concat(ch_all_new)
        .transpose()
        .take( params.max_tables )
        .set{ ch_tables }
    
    /*
    =============================================================================================================================
        COLLECT FILE INFORMATION
    =============================================================================================================================
    */
    // MODULE: Determine columns that contain Google file paths for each new table
    COL_FILES (
        ch_tables
    )
    // Combine all identified file paths with the manifest info
    ch_manifest
        .map{ tuple(it.terra_project, it.terra_workspace, it.terra_workflow_name, it.dest_workflow_name) }
        .join(COL_FILES.out.files, by: [0,1])
        .splitCsv(elem: 4, header: false)
        .map{ project, workspace, t_workflow, d_workflow, meta -> [ project, workspace, t_workflow, d_workflow, meta[0], meta[1] ] }
        .transpose()
        .combine( ch_manifest.map{ tuple(it.terra_project, it.terra_workspace, it.terra_workflow_name, it.sample_patterns) }, by: [0,1,2] )
        .set{ ch_files }
    
    params.dev ? ch_files.take(5).set{ ch_files } : ch_files
    
    // MODULE: Extract the sample IDs based on supplied regex patterns. Only return samples that matched these patterns.
    EXTRACT_ID (
        ch_files.map{ project, workspace, t_workflow, d_workflow, sample, file, patterns -> [ sample, patterns ] }.unique()
    )

    // Prepare channel for filtering
    ch_files
        .map{ project, workspace, t_workflow, d_workflow, sample, file, patterns -> [ sample, project, workspace, t_workflow, d_workflow, file ] } // drop the regex patterns
        .combine(EXTRACT_ID.out.ids, by: 0) // combine with extracted sample IDs - those not matching a supplied regex pattern will be "None"
        .map{ sample, project, workspace, t_workflow, d_workflow, file, id -> [ project, workspace, t_workflow, d_workflow, sample, id, file ] } // reorder fields
        .map{ project, workspace, t_workflow, d_workflow, sample, id, file ->  [ project, workspace, t_workflow, d_workflow, file.tokenize('/')[4], sample, id, file ]} // Extract the workflow name from the Google URL path
        .set{ ch_files }
    // Filter 1: Sample ID regex
    ch_files
        .filter{ project, workspace, t_workflow, d_workflow, a_workflow, sample, id, file -> id == "None"  }
        .set{ ch_regex }
    ch_files
        .filter{ project, workspace, t_workflow, d_workflow, a_workflow, sample, id, file -> id != "None"  }
        .set{ ch_files }
    // Filter 2: Workflow name
    ch_files
        .filter{ project, workspace, t_workflow, d_workflow, a_workflow, sample, id, file -> t_workflow != a_workflow  } // filter files that match the target workflow
        .set{ ch_wkflw }
    ch_files
        .filter{ project, workspace, t_workflow, d_workflow, a_workflow, sample, id, file -> t_workflow == a_workflow  } // filter files that match the target workflow
        .set{ ch_files }
    // Combine filtered samples & remove unneeded fields
    ch_regex
        .combine(ch_wkflw)
        .map{ project, workspace, t_workflow, d_workflow, a_workflow, sample, id, file ->  [ file, project, workspace, d_workflow, sample, id ]}
        .set{ ch_filtered }
    // Remove unneeded fields from ch_files
    ch_files
        .map{ project, workspace, t_workflow, d_workflow, a_workflow, sample, id, file ->  [ file, project, workspace, d_workflow, sample, id ]}
        .set{ ch_files }

    // MODULE: Get timestamp for each file from Google
    GET_TIMESTAMP (
        ch_files.map{ file, project, workspace, d_workflow, sample, id -> [ file, params.google_cred ? params.google_cred : "${workflow.homeDir}/.config/gcloud/" ] }
    )

    GET_TIMESTAMP
        .out
        .timestamp
        .splitCsv(header: false)
        .set{ timestamps }
    
    ch_files
        .join( timestamps, by: 0 )
        .map{ gs_file, project, workspace, d_workflow, sample, id, timestamp -> [ id, sample, file(gs_file).getName(), gs_file, timestamp, workspace, d_workflow, params.google_cred ? params.google_cred : "${workflow.homeDir}/.config/gcloud/" ] }
        .set{ ch_files }

    /*
    =============================================================================================================================
        PUSH FILES, METADATA, & NEW TERRA TABLES
    =============================================================================================================================
    */
    if (!params.dryrun){
        // MODULE: Push Google files to results directory
        PUSH_FILES (
            ch_files
        )

        // MODULE: Push metadata file to results directory
        Channel.of( ["ID",
                    "ALT_ID",
                    "FILE",
                    "ORIGIN_PATH",
                    "STAGED_PATH",
                    "CURRENT_PATH",
                    "TIMESTAMP",
                    "PLATFORM",
                    "WORKSPACE",
                    "WORKFLOW" ] )
            .concat(PUSH_FILES.out.metadata)
            .map{ 
                id, 
                alt_id,
                file,
                origin_path,
                staged_path,
                current_path,
                timestamp,
                platform,
                workspace,
                workflow ->
                id+","+alt_id+","+file+","+origin_path+","+current_path+","+timestamp+","+platform+","+workspace+","+workflow
                }
            .collectFile(name: "meta_${params.run_time}.csv", sort: 'index', newLine: true)
            .set{ ch_metadata }

        PUSH_META (
            ch_metadata
        )
        // MODULE: Push new Terra tables to results directory
        PUSH_TABLES (
            ch_tables.groupTuple(by:[0,1]).combine(PUSH_META.out.wait) // forces this to wait till the end when all files have been transferred
        )
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow.onComplete {
    if (params.email || params.email_on_fail) {
         NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
