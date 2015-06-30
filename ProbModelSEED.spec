/*
=head1 ProbModelSEED	
*/
module ProbModelSEED {
    /*********************************************************************************
    Universal simple type definitions
   	*********************************************************************************/
    /* indicates true or false values, false <= 0, true >=1 */
    typedef int bool;
    
    /* Reference to location in PATRIC workspace (e.g. /home/chenry/models/MyModel)*/
    typedef string ref;
    
    /* Standard perl timestamp (e.g. 2015-03-21-02:14:53)*/
    typedef string Timestamp;
    
    /* ID of gapfilling solution */
    typedef string gapfill_id;
    
    /* ID of FBA study */
    typedef string fba_id;
    
    /* ID of model edits */
    typedef string edit_id;
    
    /* An enum of commands to manage gapfilling solutions [D/I/U]; D = delete, I = integrate, U = unintegrate*/
    typedef string gapfill_command;
    
    /* ID of reaction in model */
    typedef string reaction_id;

	/* ID of compound in model */
    typedef string compound_id;
    
    /* ID of feature in model */
    typedef string feature_id;
    
    /* ID of compartment in model */
    typedef string compartment_id;
    
	/* ID of gene in model */
	typedef string gene_id;

	/* ID of biomass reaction in model */
	typedef string biomass_id;

    /* An enum of directions for reactions [</=/>]; < = reverse, = = reversible, > = forward*/
    typedef string reaction_direction;
    
    /* Login name for user */
	typedef string Username;

	/* Name assigned to an object saved to a workspace */
	typedef string ObjectName;

	/* Unique UUID assigned to every object in a workspace on save - IDs never reused */
	typedef string ObjectID;

	/* Specified type of an object (e.g. Genome) */
	typedef string ObjectType;

	/* Size of the object */
	typedef int ObjectSize;

	/* Generic type containing object data */
	typedef string ObjectData;

	/* Path to any object in workspace database */
	typedef string FullObjectPath;

	/* This is a key value hash of user-specified metadata */
	typedef mapping<string,string> UserMetadata;

	/* This is a key value hash of automated metadata populated based on object type */
	typedef mapping<string,string> AutoMetadata;

    /* User permission in worksace (e.g. w - write, r - read, a - admin, n - none) */
	typedef string WorkspacePerm;
    
    /*********************************************************************************
    Complex data structures to support functions
   	*********************************************************************************/
    
    typedef structure {
		ref reaction;
		reaction_direction direction;
		string compartment;
    } gapfill_reaction;
    
    typedef structure {
		Timestamp rundate;
		gapfill_id id;
		ref ref;
		ref media_ref;
		bool integrated;
		int integrated_solution;
		list<list<gapfill_reaction>> solution_reactions;
    } gapfill_data;
        
    typedef structure {
		Timestamp rundate;
		fba_id id;
		ref ref;
		float objective;
		ref media_ref;
		string objective_function;
    } fba_data;
    
    typedef structure {
		reaction_id id;
		list<tuple<string compound,float coefficient,string compartment>> reagents;
		list<list<list<feature_id> > > gpr;
		reaction_direction direction;
    } edit_reaction;
    
    typedef structure {
		Timestamp rundate;
		edit_id id;
		ref ref;
		list<reaction_id> reactions_to_delete;
		mapping<reaction_id,reaction_direction> altered_directions;
		mapping<reaction_id,list<list<list<feature_id> > > > altered_gpr;
		list<edit_reaction> reactions_to_add;
		mapping<compound_id,tuple<float,compartment_id>> altered_biomass_compound;
    } edit_data;
    
    typedef structure {
 		Timestamp rundate;
		string id;
		string source;
		string source_id;
		string name;
		string type;
		ref ref;
		ref genome_ref;
		ref template_ref;
		int fba_count;
		int integrated_gapfills;
		int unintegrated_gapfills;
		int gene_associated_reactions;
		int gapfilled_reactions;
		int num_genes;
		int num_compounds;
		int num_reactions;	
		int num_biomasses;			
		int num_biomass_compounds;
		int num_compartments;
		list<string> biomasses;
		list<string> reactions;
		list<string> genes;
		list<string> biomasscpds;
    } ModelStats;

	typedef structure {
		reaction_id id;
		string name;
		string definition;
		string gpr;
		list<gene_id> genes;
	} model_reaction;

	typedef structure {
		compound_id id;
		string name;
		string formula;
		float charge;
	} model_compound;

	typedef structure {
		gene_id id;
		list<reaction_id> reactions;
	} model_gene;

	typedef structure {
		compartment_id id;
		string name;
		float pH;
		float potential;
	} model_compartment;

	typedef structure {
		biomass_id id;
		list<tuple<compound_id compound, float coefficient, compartment_id compartment>> compounds;
	} model_biomass;

	typedef structure {
		ref ref;
		list<model_reaction> reactions;
		list<model_compound> compounds;
		list<model_gene> genes;
		list<model_compartment> compartments;
		list<model_biomass> biomasses;
	} model_data;
    
    /* ObjectMeta: tuple containing information about an object in the workspace 

	ObjectName - name selected for object in workspace
	ObjectType - type of the object in the workspace
	FullObjectPath - full path to object in workspace, including object name
	Timestamp creation_time - time when the object was created
	ObjectID - a globally unique UUID assigned to every object that will never change even if the object is moved
	Username object_owner - name of object owner
	ObjectSize - size of the object in bytes or if object is directory, the number of objects in directory
	UserMetadata - arbitrary user metadata associated with object
	AutoMetadata - automatically populated metadata generated from object data in automated way
	WorkspacePerm user_permission - permissions for the authenticated user of this workspace.
	WorkspacePerm global_permission - whether this workspace is globally readable.
	string shockurl - shockurl included if object is a reference to a shock node
	
	*/
	typedef tuple<ObjectName,ObjectType,FullObjectPath,Timestamp creation_time,ObjectID,Username object_owner,ObjectSize,UserMetadata,AutoMetadata,WorkspacePerm user_permission,WorkspacePerm global_permission,string shockurl> ObjectMeta;

	/*********************************************************************************
    Functions for model stats
   	*********************************************************************************/

	/* 
    	FUNCTION: print_model_stats
    	DESCRIPTION: This function prints stats on a list of input models
    	
    	REQUIRED INPUTS:
		list<ref> models - list of references to models to print stats for
		
	*/
    typedef structure {
		list<ref> models;
    } print_model_stats_params;
    authentication required;
    funcdef print_model_stats(print_model_stats_params input) returns (mapping<ref,ModelStats> output);

    /*********************************************************************************
    Functions for managing gapfilling studies
   	*********************************************************************************/
    
    /* 
    	FUNCTION: list_gapfill_solutions
    	DESCRIPTION: This function lists all the gapfilling results associated with model
    	
    	REQUIRED INPUTS:
		ref model - reference to model for which to list gapfilling
		
	*/
    typedef structure {
		ref model;
    } list_gapfill_solutions_params;
    authentication required;
    funcdef list_gapfill_solutions(list_gapfill_solutions_params input) returns (list<gapfill_data> output);

	/* 
		FUNCTION: manage_gapfill_solutions
		DESCRIPTION: This function manages the gapfill solutions for a model and returns gapfill solution data
		
		REQUIRED INPUTS:
		ref model - reference to model to integrate solutions for
		mapping<gapfill_id,gapfill_command> commands - commands to manage gapfill solutions
		
		OPTIONAL INPUTS:
		mapping<gapfill_id,int> selected_solutions - solutions to integrate
	*/
    typedef structure {
		ref model;
		mapping<gapfill_id,gapfill_command> commands;
		mapping<gapfill_id,int> selected_solutions;
    } manage_gapfill_solutions_params;
    authentication required;
	funcdef manage_gapfill_solutions(manage_gapfill_solutions_params input) returns (mapping<gapfill_id,gapfill_data> output);
	
	/*********************************************************************************
    Functions for managing FBA studies
   	*********************************************************************************/
	
	/* 
    	FUNCTION: list_fba_studies
    	DESCRIPTION: This function lists all the FBA results associated with model
    	
    	REQUIRED INPUTS:
		ref model - reference to model for which to list FBA
		
	*/
    typedef structure {
		ref model;
    } list_fba_studies_params;
    authentication required;
    funcdef list_fba_studies(list_fba_studies_params input) returns (list<fba_data> output);

	/* 
		FUNCTION: delete_fba_studies
		DESCRIPTION: This function deletes fba studies associated with model
		
		REQUIRED INPUTS:
		ref model - reference to model to integrate solutions for
		list<fba_id> fbas - list of FBA studies to delete	
	*/
    typedef structure {
		ref model;
		mapping<gapfill_id,gapfill_command> commands;
    } delete_fba_studies_params;
    authentication required;
	funcdef delete_fba_studies(delete_fba_studies_params input) returns (mapping<fba_id,fba_data> output);
	
	/*********************************************************************************
    Functions for export of model data
   	*********************************************************************************/
	
	/* 
		FUNCTION: export_model
		DESCRIPTION: This function exports a model in the specified format
		
		REQUIRED INPUTS:
		ref model - reference to model to export
		string format - format to export model in
		bool to_shock - load exported file to shock and return shock url
	*/
    typedef structure {
		ref model;
		string format;
		bool to_shock;
    } export_model_params;
    authentication required;
	funcdef export_model(export_model_params input) returns (string output);

	/* 
		FUNCTION: export_media
		DESCRIPTION: This function exports a media in TSV format
		
		REQUIRED INPUTS:
		ref media - reference to media to export
		bool to_shock - load exported file to shock and return shock url
	*/
    typedef structure {
		ref media;
		bool to_shock;
    } export_media_params;
    authentication required;
	funcdef export_media(export_media_params input) returns (string output);
	
	/*********************************************************************************
    Functions for managing models
   	*********************************************************************************/

	/*
		FUNCTION: get_model
		DESCRIPTION: This function gets model data

		REQUIRED INPUTS:
		ref model - reference to model to get

	*/		
	typedef structure {
		ref model;
	} get_model_params;
	authentication required;
	funcdef get_model(get_model_params input) returns (model_data output);

	/* 
    	FUNCTION: delete_model
    	DESCRIPTION: This function deletes a model specified by the user
    	
    	REQUIRED INPUTS:
		ref model - reference to model to delete
		
	*/
    typedef structure {
		ref model;
    } delete_model_params;
    authentication required;
    funcdef delete_model(delete_model_params input) returns (ObjectMeta output);
    
    /* 
    	FUNCTION: list_models
    	DESCRIPTION: This function lists all models owned by the user
    	
    	REQUIRED INPUTS:

		
	*/
    authentication required;
    funcdef list_models() returns (list<ModelStats> output);
	
	/*********************************************************************************
    Functions for editing models
   	*********************************************************************************/
	
	/* 
    	FUNCTION: list_model_edits
    	DESCRIPTION: This function lists all model edits submitted by the user
    	
    	REQUIRED INPUTS:
		ref model - reference to model for which to list edits
		
	*/
    typedef structure {
		ref model;
    } list_model_edits_params;
    authentication required;
    funcdef list_model_edits(list_model_edits_params input) returns (list<edit_data> output);

	/* 
		FUNCTION: manage_model_edits
		DESCRIPTION: This function manages edits to model submitted by user
		
		REQUIRED INPUTS:
		ref model - reference to model to integrate solutions for
		mapping<edit_id,gapfill_command> commands - list of edit commands
		
		OPTIONAL INPUTS:
		edit_data new_edit - list of new edits to add
	*/
    typedef structure {
		ref model;
		mapping<edit_id,gapfill_command> commands;
		edit_data new_edit;
    } manage_model_edits_params;
    authentication required;
	funcdef manage_model_edits(manage_model_edits_params input) returns (mapping<edit_id,edit_data> output);

	/*********************************************************************************
	Functions corresponding to modeling apps
   	*********************************************************************************/
	/* 
		FUNCTION: ModelReconstruction
		DESCRIPTION: This function runs the model reconstruction app directly. See app service for detailed specs.
	*/
    typedef structure {
		ref genome;
    } ModelReconstruction_params;
    authentication required;
	funcdef ModelReconstruction(ModelReconstruction_params input) returns (ObjectMeta output);
	
	/* 
		FUNCTION: FluxBalanceAnalysis
		DESCRIPTION: This function runs the flux balance analysis app directly. See app service for detailed specs.
	*/
    typedef structure {
		ref model;
    } FluxBalanceAnalysis_params;
    authentication required;
	funcdef FluxBalanceAnalysis(FluxBalanceAnalysis_params input) returns (ObjectMeta output);
	
	/* 
		FUNCTION: GapfillModel
		DESCRIPTION: This function runs the gapfilling app directly. See app service for detailed specs.
	*/
    typedef structure {
		ref model;
    } GapfillModel_params;
    authentication required;
	funcdef GapfillModel(GapfillModel_params input) returns (ObjectMeta output);
};