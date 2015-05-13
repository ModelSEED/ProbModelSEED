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
    typedef string timestamp;
    
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
    
    /* An enum of directions for reactions [</=/>]; < = reverse, = = reversible, > = forward*/
    typedef string reaction_direction;
    
    /*********************************************************************************
    Complex data structures to support functions
   	*********************************************************************************/
    
    typedef structure {
		ref reaction;
		reaction_direction direction;
		string compartment;
    } gapfill_reaction;
    
    typedef structure {
		timestamp rundate;
		gapfill_id id;
		ref gapfill;
		ref media;
		bool integrated;
		int integrated_solution;
		list<list<gapfill_reaction>> solution_reactions;
    } gapfill_data;
        
    typedef structure {
		timestamp rundate;
		fba_id id;
		ref fba;
		float objective;
		ref media;
		string objective_function;
    } fba_data;
    
    typedef structure {
		reaction_id id;
		list<tuple<string compound,float coefficient,string compartment>> reagents;
		list<list<list<feature_id> > > gpr;
		reaction_direction direction;
    } edit_reaction;
    
    typedef structure {
		timestamp rundate;
		edit_id id;
		ref edit;
		list<reaction_id> reactions_to_delete;
		mapping<reaction_id,reaction_direction> altered_directions;
		mapping<reaction_id,list<list<list<feature_id> > > > altered_gpr;
		list<edit_reaction> reactions_to_add;
		mapping<compound_id,tuple<float,compartment_id>> altered_biomass_compound;
    } edit_data;

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
    funcdef list_gapfill_solutions(list_gapfill_solutions_params input) returns (mapping<gapfill_id,gapfill_data> output);

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
    funcdef list_fba_studies(list_fba_studies_params input) returns (mapping<fba_id,fba_data> output);

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
    funcdef list_model_edits(list_model_edits_params input) returns (mapping<edit_id,edit_data> output);

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
};