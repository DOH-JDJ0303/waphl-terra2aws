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

    INPUT_CHECK ( 
        params.input
    )
    
    INPUT_CHECK
        .out
        .manifest
        .set{ ch_manifest }

    PULL_TABLES (
        ch_manifest.map{ tuple(it.terra_project, it.terra_workspace) }
    )

    PULL_TABLES.out.tables
        .map{ project, workspace, tables -> [ project, workspace, tables, file(params.outdir).resolve("terra_tbls").resolve(project).resolve(workspace).exists() ? file(params.outdir).resolve("terra_tbls").resolve(project).resolve(workspace) : null ] }
        .set{ ch_tables }
        
    ch_tables.filter{ project, workspace, new_tables, old_tables -> !old_tables }.map{ project, workspace, new_tables, old_tables -> [ project, workspace, new_tables ] }.set{ ch_all_new }
    ch_tables.filter{ project, workspace, new_tables, old_tables -> old_tables }.set{ ch_some_new }
    
    CMP_TABLES (
        ch_some_new
    )

    CMP_TABLES.out.tables.concat(ch_all_new).transpose().view()

    COL_FILES (
        CMP_TABLES.out.tables.concat(ch_all_new).transpose()
    )

    ch_manifest
        .map{ tuple(it.terra_project, it.terra_workspace, it.terra_workflow_name, it.dest_workflow_name) }
        .join(COL_FILES.out.files, by: [0,1])
        .splitCsv(elem: 4, header: false)
        .map{ project, workspace, t_workflow, d_workflow, meta -> [ project, workspace, t_workflow, d_workflow, meta[0], meta[1] ] }
        .transpose()
        .combine( ch_manifest.map{ tuple(it.terra_project, it.terra_workspace, it.terra_workflow_name, it.sample_patterns) }, by: [0,1,2] )
        .set{ ch_files }
    
    EXTRACT_ID (
        ch_files.map{ project, workspace, t_workflow, d_workflow, sample, file, patterns -> [ sample, patterns ] }.unique()
    )

    ch_files
        .map{ project, workspace, t_workflow, d_workflow, sample, file, patterns -> [ sample, project, workspace, t_workflow, d_workflow, file ] }
        .combine(EXTRACT_ID.out.ids, by: 0)
        .map{ sample, project, workspace, t_workflow, d_workflow, file, id -> [ project, workspace, t_workflow, d_workflow, sample, id, file ] }
        .filter{ project, workspace, t_workflow, d_workflow, sample, id, file -> file.startsWith("gs://") & id != "None"  }
        .map{ project, workspace, t_workflow, d_workflow, sample, id, file ->  [ project, workspace, t_workflow, d_workflow, file.tokenize('/')[4], sample, id, file ]}
        .filter{ project, workspace, t_workflow, d_workflow, a_workflow, sample, id, file -> t_workflow == a_workflow  }
        .map{ project, workspace, t_workflow, d_workflow, a_workflow, sample, id, file ->  [ file, project, workspace, t_workflow, d_workflow, sample, id ]}
        .set{ ch_files }

    GET_TIMESTAMP (
        ch_files.map{ file, project, workspace, t_workflow, d_workflow, sample, id -> file }
    )

    GET_TIMESTAMP
        .out
        .timestamp
        .splitCsv(header: false)
        .set{ timestamps }
    
    ch_files
        .join( timestamps, by: 0 )
        .map{ gs_file, project, workspace, t_workflow, d_workflow, sample, id, timestamp -> [ id, sample, file(gs_file).getName(), gs_file, timestamp, workspace, d_workflow ] }
        .set{ ch_files }

    PUSH_FILES (
        ch_files
    )
    
    run_time = System.currentTimeMillis()
    Channel.of( [ "ID",
                  "ALT_ID",
                  "FILE",
                  "ORIGIN_PATH",
                  "CURRENT_PATH",
                  "TIMESTAMP",
                  "PLATFORM",
                  "WORKSPACE",
                  "WORKFLOW" ] )
        .concat(PUSH_FILES.out.metadata)
        .map{ id, 
              alt_id,
              file,
              origin_path,
              current_path,
              timestamp,
              platform,
              workspace,
              workflow ->
              id+","+alt_id+","+file+","+origin_path+","+current_path+","+timestamp+","+platform+","+workspace+","+workflow
            }
        .collectFile(name: run_time+"-meta.csv", sort: 'index', newLine: true)
        .set{ ch_metadata }
    
    ch_metadata.view()
    
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
