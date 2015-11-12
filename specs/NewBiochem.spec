/*
@author chenry
*/
module KBaseBiochem {
	typedef int bool;
	/*
		Reference to a reaction object in a biochemistry
		@id subws KBaseBiochem.Biochemistry.reactions.[*].id
	*/
    typedef string reaction_ref;
	/*
		Reference to a cue object in a biochemistry
		@id subws KBaseBiochem.Biochemistry.cues.[*].id
	*/
    typedef string cue_ref;
	/*
		Reference to a compound object in a biochemistry
		@id subws KBaseBiochem.Biochemistry.compounds.[*].id
	*/
    typedef string compound_ref;
    /*
		Source ID
		@id external
	*/
    typedef string source_id;
    
    /* 
    	Compound object
    	
    	@optional md5 formula unchargedFormula mass deltaG deltaGErr abstractCompound_ref comprisedOfCompound_refs structure_ref cues pkas pkbs
		@searchable ws_subset id isCofactor name abbreviation md5 formula unchargedFormula mass defaultCharge deltaG abstractCompound_ref comprisedOfCompound_refs structure_ref cues
    */
    typedef structure {
    	string id;
    	bool isCofactor;
    	string name;
    	string abbreviation;
    	string md5;
    	string formula;
    	string unchargedFormula;
    	string structure;
    	float mass;
    	float defaultCharge;
    	float deltaG;
    	float deltaGErr;
    	compound_ref abstractCompound_ref;
    	list<compound_ref> comprisedOfCompound_refs;
    	mapping<string,list<string>> aliases;
    	mapping<cue_ref,float> cues;
    	mapping<int,list<float>> pkas;
    	mapping<int,list<float>> pkbs;
    } Compound;
    
    /* 
    	Reactant object
    	
		@searchable ws_subset compound_ref compartment_ref coefficient isCofactor
    */
    typedef structure {
		compound_ref compound_ref;
		int compartment_index;
		float coefficient;
		bool isCofactor;
	} Reagent;
    
    /* 
    	Reaction object
    	
    	@optional md5 deltaG deltaGErr abstractReaction_ref cues
		@searchable ws_subset id name abbreviation md5 direction thermoReversibility status defaultProtons deltaG abstractReaction_ref cues
		@searchable ws_subset reagents.[*].(compound_ref,compartment_ref,coefficient,isCofactor)
    */
    typedef structure {
    	string id;
    	string name;
    	string abbreviation;
    	string md5;
    	string direction;
    	string thermoReversibility;
    	string status;
    	float deltaG;
    	float deltaGErr;
    	reaction_ref abstractReaction_ref;
    	mapping<string,list<string>> aliases;
    	mapping<cue_ref,float> cues;
    	list<Reagent> reagents; 
    } Reaction;
    
    /* 
    	Cue object
    	
    	@optional mass deltaGErr deltaG defaultCharge structure_key structure_data structure_type
		@searchable ws_subset structure_key id name abbreviation formula unchargedFormula mass defaultCharge deltaG smallMolecule priority structure_key structure_data
    */
    typedef structure {
    	string id;
    	string name;
    	string abbreviation;
    	string formula;
    	string unchargedFormula;
    	float mass;
    	float defaultCharge;
    	float deltaG;
    	float deltaGErr;
    	bool smallMolecule;
    	int priority;
    	string structure_key;
    	string structure_data;
    	string structure_type;
    } Cue;
    
    /* 
    	MediaCompound object
    */
	typedef structure {
		string id;
		string type;
		compound_ref compound_ref;
		float concentration;
		float maxFlux;
		float minFlux;
	} MediaCompound;
	
	/* 
    	MediaReagent object
    	
    	@optional molecular_weight concentration_units concentration associated_compounds
    */
	typedef structure {
		string id;
		string name;
		float concentration;
		string concentration_units;
		float molecular_weight;
		mapping<string,float> associated_compounds;
	} MediaReagent;
	
	/* 
    	Media object
    	
    	@optional reagents atmosphere_addition atmosphere temperature pH_data isAerobic protocol_link source source_id 	
		@metadata ws source_id as Source ID
		@metadata ws source as Source
		@metadata ws name as Name
		@metadata ws temperature as Temperature
		@metadata ws isAerobic as Is Aerobic
		@metadata ws isMinimal as Is Minimal
		@metadata ws isDefined as Is Defined
		@metadata ws length(mediacompounds) as Number compounds
    */
	typedef structure {
		string id;
		string name;
		source_id source_id;
		string source;
		string protocol_link;
		bool isDefined;
		bool isMinimal;
		bool isAerobic;
		string type;
		string pH_data;
		float temperature;
		string atmosphere;
		string atmosphere_addition;
		list<MediaReagent> reagents;
		list<MediaCompound> mediacompounds;
	} Media;
	
	/* 
    	CompoundSet object
    	
    	@searchable ws_subset id name class compound_refs type
    */
	typedef structure {
		string id;
		string name;
		string class;
		string type;
		list<compound_ref> compound_refs;
	} CompoundSet;
	
	/* 
    	ReactionSet object
    	
    	@searchable ws_subset id name class reaction_refs type
    */
	typedef structure {
		string id;
		string name;
		string class;
		string type;
		list<reaction_ref> reaction_refs;
	} ReactionSet;
    
    /* 
    	Biochemistry object
    	
    	@optional description name
    	@searchable ws_subset compounds.[*].(id,name)
    	@searchable ws_subset reactions.[*].(id)
    	@searchable ws_subset cues.[*].(id,name,smallMolecule)
    	@searchable ws_subset reactionSets.[*].(id,name,class,reaction_refs,type)
    	@searchable ws_subset compoundSets.[*].(id,name,class,compound_refs,type)
    */
    typedef structure {
		string id;
		string name;
		string description;
		
		list<Compound> compounds;
		list<Reaction> reactions;
		list<ReactionSet> reactionSets;
		list<CompoundSet> compoundSets;
		list<Cue> cues;
	} Biochemistry;
};