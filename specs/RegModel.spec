#include <KBCHEM.spec>
/*
@author chenry
*/
module KBREG {
    /*
		Reference to a model template
		@id ws KBFBA.Template
	*/
    typedef string template_ref;
    /*
		Reference to an OTU in a metagenome
		@id subws KBMGA.Metagenome.otus.[*].id
	*/
    typedef string metagenome_otu_ref;
    /*
		Reference to a metagenome object
		@id ws KBMGA.Metagenome
	*/
    typedef string metagenome_ref;
    /*
		Reference to a feature of a genome object
		@id subws KBGA.Genome.features.[*].id
	*/
    typedef string feature_ref;
	/*
		Reference to a gapgen object
		@id ws KBFBA.GapgenFormulation
	*/
    typedef string gapgen_ref;
	/*
		Reference to a gapfilling object
		@id ws KBFBA.GapfillingFormulation
	*/
    typedef string gapfill_ref;
	/*
		Reference to a complex object in a mapping
		@id subws KBGA.Mapping.complexes.[*].id
	*/
    typedef string complex_ref;
	/*
		Reference to a reaction object in a biochemistry
		@id subws KBCHEM.Biochemistry.reactions.[*].id
	*/
    typedef string reaction_ref;
	/*
		Reference to a compartment object in a model
		@id subws KBFBA.FBAModel.modelcompartments.[*].id
	*/
    typedef string modelcompartment_ref;
	/*
		Reference to a compartment object in a biochemistry
		@id subws KBCHEM.Biochemistry.compartments.[*].id
	*/
    typedef string compartment_ref;
	/*
		Reference to a compound object in a model
		@id subws KBFBA.FBAModel.modelcompounds.[*].id
	*/
    typedef string modelcompound_ref;
	/*
		KBase genome ID
		@id kb
	*/
    typedef string genome_id;
    /*
		Genome ID
		@id external
	*/
    typedef string biomass_id;
    /*
		Model compartment ID
		@id external
	*/
    typedef string modelcompartment_id;
    /*
		Model compound ID
		@id external
	*/
    typedef string modelcompound_id;
    /*
		Model reaction ID
		@id external
	*/
    typedef string modelreaction_id;
    /*
		Source ID
		@id external
	*/
    typedef string source_id;
    /*
		Gapgen ID
		@id kb
	*/
    typedef string gapgen_id;
	/*
		Gapfill ID
		@id kb
	*/
    typedef string gapfill_id;
    /*
		FBAModel ID
		@id kb
	*/
    typedef string fbamodel_id;
	
    
};