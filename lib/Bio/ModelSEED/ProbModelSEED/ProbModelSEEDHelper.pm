package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
use strict;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

use Bio::P3::Workspace::WorkspaceClientExt;
use JSON::XS;
use Data::Dumper;
use Log::Log4perl;
use Bio::KBase::ObjectAPI::utilities;
use Bio::KBase::ObjectAPI::PATRICStore;

#****************************************************************************
#Getter setters for parameters
#****************************************************************************
sub workspace_url {
	my ($self) = @_;
	return $self->{_params}->{"workspace-url"};
}
sub token {
	my ($self) = @_;
	return $self->{_params}->{token};
}
sub shock_url {
	my ($self) = @_;
	return $self->{_params}->{"shock-url"};
}
sub adminmode {
	my ($self,$adminmode) = @_;
	return $self->{_params}->{adminmode};
}

#****************************************************************************
#Data retrieval and storage functions functions
#****************************************************************************
sub save_object {
	my($self, $ref,$data,$type,$metadata) = @_;
	my $object = $self->PATRICStore()->save_object($data,$ref,$metadata,$type,1);
	return $object;
}
sub copy_object {
	my($self,$ref,$destination,$recursive) = @_;
	return $self->workspace_service()->copy({
		objects => [[$ref,$destination]],
		adminmode => $self->{_params}->{adminmode},
		overwrite => 1,
		recursive => $recursive,
	});
}
sub get_object {
	my($self, $ref,$type,$options) = @_;
	my $object = $self->PATRICStore()->get_object($ref,$options);
	if (defined($type)) {
		my $objtype = $self->PATRICStore()->get_object_type($ref);
		if ($objtype ne $type) {
			$self->error("Type retrieved (".$objtype.") does not match specified type (".$type.")!");
		}
	}
	return $object;
}
sub get_model {
	my($self, $ref) = @_;
	my $model = $self->get_object($ref,undef,{refreshcache => 1});
    if (!defined($model)) {
    	$self->error("Model retrieval failed!");
    }
	return $model;
}
sub get_genome {
	my($self, $ref) = @_;
	my $obj;
	if ($ref =~ m/^PATRICSOLR:(.+)/) {
    	return $self->retrieve_PATRIC_genome($1);
	} else {
		$obj = $self->get_object($ref);
	    if (defined($obj) && ref($obj) ne "Bio::KBase::ObjectAPI::KBaseGenomes::Genome" && defined($obj->{output_files})) {
	    	my $output = $obj->{output_files};
	    	for (my $i=0; $i < @{$obj->{output_files}}; $i++) {
	    		if ($obj->{output_files}->[$i]->[0] =~ m/\.genome$/) {
	    			$ref = $obj->{output_files}->[$i]->[0];
	    		}
	    	}
	    	$obj = $self->get_object($ref,"genome");
	    }
	}
    if (!defined($obj)) {
    	$self->error("Genome retrieval failed!");
    }
	return $obj;
}
sub get_model_meta {
	my($self, $ref) = @_;
	my $metas = $self->workspace_service()->get({
		objects => [$ref],
		metadata_only => 1,
		adminmode => $self->{_params}->{adminmode}
	});
	if (!defined($metas->[0]->[0]->[0])) {
    	return undef;
    }
	return $metas->[0]->[0];
}

#This function retrieves or sets the biochemistry object in the server memory, making retrieval of biochemsitry very fast
sub biochemistry {
	my($self,$bio) = @_;
	if (defined($bio)) {
		#In this case, the cache is being overwritten with an existing biochemistry object (e.g. ProbModelSEED servers will call this)
		$self->{_cached_biochemistry} = $bio;
		$self->PATRICStore()->cache()->{$self->{_params}->{biochemistry}}->[0] = $bio->wsmeta();
		$self->PATRICStore()->cache()->{$self->{_params}->{biochemistry}}->[1] = $bio;
	}
	if (!defined($self->{_cached_biochemistry})) {
		$self->{_cached_biochemistry} = $self->get_object($self->{_params}->{biochemistry},"biochemistry");		
	}
	return $self->{_cached_biochemistry};
}

sub workspace_service {
	my($self) = @_;
	if (!defined($self->{_workspace_service})) {
		$self->{_workspace_service} = Bio::P3::Workspace::WorkspaceClientExt->new($self->workspace_url(),token => $self->token());
	}
	return $self->{_workspace_service};
}
sub PATRICStore {
	my($self) = @_;
	if (!defined($self->{_PATRICStore})) {
		my $cachetarg = {};
		for (my $i=0; $i < @{$self->{_params}->{cache_targets}}; $i++) {
			$cachetarg->{$self->{_params}->{cache_targets}->[$i]} = 1;
		}
		$self->{_PATRICStore} = Bio::KBase::ObjectAPI::PATRICStore->new({
			data_api_url => $self->{_params}->{data_api_url},
			workspace => $self->workspace_service(),
			adminmode => $self->{_params}->{adminmode},
			file_cache => $self->{_params}->{file_cache},
    		cache_targets => $cachetarg
		});
	}
	return $self->{_PATRICStore};
}
#****************************************************************************
#Utility functions
#****************************************************************************
sub validate_args {
	my ($self,$args,$mandatoryArguments,$optionalArguments) = @_;
	return Bio::KBase::ObjectAPI::utilities::ARGS($args,$mandatoryArguments,$optionalArguments);
}
sub error {
	my($self,$msg) = @_;
	Bio::KBase::ObjectAPI::utilities::error($msg);
}
sub config {
	my($self) = @_;
	$self->{_params};
}

#****************************************************************************
#Research functions
#****************************************************************************
=head3 delete_model

Definition:
	Genome = $self->delete_model(ref Model);
Description:
	Deletes the specified model
		
=cut
sub delete_model {
	my($self,$model) = @_;
	my $modelfolder;
	if ($model =~ m/^(.+\/)([^\/]+)$/) {
		$modelfolder = $1.".".$2;
	}
	# Not quite sure what will happen if the model or modelfolder does not exist 
	my $output = $self->workspace_service()->delete({
		objects => [$model, $modelfolder],
		deleteDirectories => 1,
		force => 1,
		adminmode => $self->adminmode()
	});
	# Only return metadata on model object.
	return $output->[0];
}

=head3 get_model_data

Definition:
	model_data = $self->get_model(ref modelref);
Description:
	Gets the specified model
		
=cut
sub get_model_data {
	my ($self,$modelref) = @_;
	my $model = $self->get_model($modelref);
	return $model->export({format => "condensed"});
}

sub get_model_summary {
	my ($self,$modelmeta) = @_;
	my $output = $modelmeta->[8];
	$output->{rundate} = $modelmeta->[3];
	$output->{id} = $modelmeta->[0];
	$output->{"ref"} = $modelmeta->[2].$modelmeta->[0];
	$output->{gene_associated_reactions} = ($output->{$modelmeta->[2].$modelmeta->[0]}->{num_reactions} - 22);
	$output->{gapfilled_reactions} = 0;
	$output->{fba_count} = 0;
	$output->{integrated_gapfills} = 0;
	$output->{unintegrated_gapfills} = 0;
	my $list = $self->workspace_service()->ls({
		paths => [$modelmeta->[2].".".$modelmeta->[0]."/fba"],
		excludeDirectories => 1,
		excludeObjects => 0,
		recursive => 0,
		query => {type => "fba"}
	});
	if (defined($list->{$modelmeta->[2].".".$modelmeta->[0]."/fba"})) {
		$list = $list->{$modelmeta->[2].".".$modelmeta->[0]."/fba"};
		$output->{fba_count} = @{$list};
	}
	my $list = $self->workspace_service()->ls({
		paths => [$modelmeta->[2].".".$modelmeta->[0]."/gapfilling"],
		excludeDirectories => 1,
		excludeObjects => 0,
		recursive => 0,
		query => {type => "fba"}
	});
	if (defined($list->{$modelmeta->[2].".".$modelmeta->[0]."/gapfilling"})) {
		$list = $list->{$modelmeta->[2].".".$modelmeta->[0]."/gapfilling"};
		for (my $k=0; $k < @{$list}; $k++) {
			my $item = $list->[$k];
			if ($item->[7]->{integrated} == 1) {
				$output->{$modelmeta->[2].$modelmeta->[0]}->{integrated_gapfills}++;
			} else {
				$output->{$modelmeta->[2].$modelmeta->[0]}->{unintegrated_gapfills}++;
			}
		}
	}
	delete $output->{reactions};
	delete $output->{genes};
	delete $output->{biomasses};		
	$output->{num_biomass_compounds} = split(/\//,$output->{biomasscpds});
	delete $output->{biomasscpds};
	return $output;
}

=head3 classify_genome

Definition:
	Genome = $self->classify_genome(string classifier,Genome genome);
Description:
	Returns the cell wall classification for genome
		
=cut
sub classify_genome {
	my($self,$classifier,$genome) = @_;
	my $data = [split(/\n/,$classifier)];
    my $headings = [split(/\t/,$data->[0])];
	my $popprob = [split(/\t/,$data->[1])];
	my $classdata = {};
	for (my $i=1; $i < @{$headings}; $i++) {
		$classdata->{classifierClassifications}->{$headings->[$i]} = {
			name => $headings->[$i],
			populationProbability => $popprob->[$i]
		};
	}
	my $cfRoleHash = {};
	for (my $i=2;$i < @{$data}; $i++) {
		my $row = [split(/\t/,$data->[$i])];
		my $searchrole = Bio::KBase::ObjectAPI::utilities::convertRoleToSearchRole($row->[0]);
		$classdata->{classifierRoles}->{$searchrole} = {
			classificationProbabilities => {},
			role => $row->[0]
		};
		for (my $j=1; $j < @{$headings}; $j++) {
			$classdata->{classifierRoles}->{$searchrole}->{classificationProbabilities}->{$headings->[$j]} = $row->[$j];
		}
	}
	my $scores = {};
	my $sum = 0;
	foreach my $class (keys(%{$classdata->{classifierClassifications}})) {
		$scores->{$class} = 0;
		$sum += $classdata->{classifierClassifications}->{$class}->{populationProbability};
	}
	my $genes = $genome->features();
	foreach my $gene (@{$genes}) {
		my $roles = $gene->roles();
		foreach my $role (@{$roles}) {
			my $searchrole = Bio::KBase::ObjectAPI::utilities::convertRoleToSearchRole($role);
			if (defined($classdata->{classifierRoles}->{$searchrole})) {
				foreach my $class (keys(%{$classdata->{classifierClassifications}})) {
					$scores->{$class} += $classdata->{classifierRoles}->{$searchrole}->{classificationProbabilities}->{$class};
				}
			}
		}
	}
	my $largest;
	my $largestClass;
	foreach my $class (keys(%{$classdata->{classifierClassifications}})) {
		$scores->{$class} += log($classdata->{classifierClassifications}->{$class}->{populationProbability}/$sum);
		if (!defined($largest)) {
			$largest = $scores->{$class};
			$largestClass = $class;
		} elsif ($largest > $scores->{$class}) {
			$largest = $scores->{$class};
			$largestClass = $class;
		}
	}
	return $largestClass;
}
=head3 retrieve_PATRIC_genome

Definition:
	Genome = $self->retrieve_PATRIC_genome(string genome);
Description:
	Returns typed object for genome in PATRIC reference database
		
=cut
sub retrieve_PATRIC_genome {
	my ($self,$genomeid) = @_;
	#Retrieving genome information
	my $data = Bio::KBase::ObjectAPI::utilities::rest_download({url => $self->config()->{data_api_url}."genome/?genome_id=".$genomeid."&http_accept=application/json",token => $self->token()});
	$data = $data->[0];
	my $perm = "n";
	my $uperm = "o";
	if ($data->{public} == 1) {
		$perm = "r";
		$uperm = "r";
	}
	$data = Bio::KBase::ObjectAPI::utilities::ARGS($data,[],{
		genome_length => 0,
		contigs => 0,
		genome_name => "Unknown",
		taxon_lineage_names => ["Unknown"],
		owner => "Unknown",
		gc_content => 0,
		publication => "Unknown",
		completion_date => "1970-01-01T00:00:00+0000"
	});
	my $meta = [
    	$genomeid,
		"genome",
		$self->config()->{data_api_url}."genome/?genome_id=".$genomeid."&http_accept=application/json",
		$data->{completion_date},
		$genomeid,
		$data->{owner},
		$data->{genome_length},
		{},
		{},
		$uperm,
		$perm
    ];
	my $genome = {
    	id => $genomeid,
		scientific_name => $data->{genome_name},
		domain => $data->{taxon_lineage_names}->[0],
		genetic_code => 11,
		dna_size => $data->{genome_length},
		num_contigs => $data->{contigs},
		contigs => [],
		contig_lengths => [],
		contig_ids => [],
		source => "PATRIC",
		source_id => $genomeid,
		md5 => "none",
		taxonomy => join(":",@{$data->{taxon_lineage_names}}),
		gc_content => $data->{gc_content},
		complete => 1,
		publications => [$data->{publication}],
		features => [],
		contigset_ref => "PATRICSOLR:CONTIGS:".$genomeid,
	};
	#Retrieving feature information
	my $start = 0;
	my $params = {};
	my $loopcount = 0;
	while ($start >= 0 && $loopcount < 100) {
		$loopcount++;#Insurance that no matter what, this loop won't run for more than 100 iterations
		my $ftrdata = Bio::KBase::ObjectAPI::utilities::rest_download({url => $self->config()->{data_api_url}."genome_feature/?genome_id=".$genomeid."&http_accept=application/json&limit(10000,$start)",token => $self->token()},$params);
		if (defined($ftrdata) && @{$ftrdata} > 0) {
			for (my $i=0; $i < @{$ftrdata}; $i++) {
				$data = $ftrdata->[$i];
				my $id = $data->{feature_id};
				if (defined($data->{seed_id})) {
					$id = $data->{seed_id};
				}
				if (defined($data->{patric_id})) {
					$id = $data->{patric_id};
				}
				my $ftrobj = {id => $id,type => "CDS",aliases=>[]};
				if (defined($data->{start})) {
					$ftrobj->{location} = [[$data->{sequence_id},$data->{start},$data->{strand},$data->{na_length}]];
				}
				if (defined($data->{feature_type})) {
					$ftrobj->{type} = $data->{feature_type};
				}
				if (defined($data->{product})) {
					$ftrobj->{function} = $data->{product};
				}
				if (defined($data->{na_sequence})) {
					$ftrobj->{dna_sequence} = $data->{na_sequence};
					$ftrobj->{dna_sequence_length} = $data->{na_length};
				}
				if (defined($data->{aa_sequence})) {
					$ftrobj->{protein_translation} = $data->{aa_sequence};
					$ftrobj->{protein_translation_length} = $data->{aa_length};
					$ftrobj->{md5} = $data->{aa_sequence_md5};
				}
				my $list = ["feature_id","alt_locus_tag","refseq_locus_tag","protein_id","figfam_id"];
				for (my $j=0; $j < @{$list}; $j++) {
					if (defined($data->{$list->[$j]})) {
						push(@{$ftrobj->{aliases}},$data->{$list->[$j]});
					}
				}
				push(@{$genome->{features}},$ftrobj);
			}
		}
		print $start."\t".@{$genome->{features}}."\t".@{$ftrdata}."\n";
		if (@{$genome->{features}} < $params->{count}) {
			$start = @{$genome->{features}};
		} else {
			$start = -1;
		}
	}
	my $genome = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genome);
	$genome->wsmeta($meta);
	$genome->_reference("PATRICSOLR:".$genomeid);
	$genome->parent($self->PATRICStore());
	return $genome;
}

=head3 build_fba_object

Definition:
	Genome = $self->build_fba_object({} params);
Description:
	Returns typed object for FBA
		
=cut
sub build_fba_object {
	my($self,$model,$params) = @_;
	my $log = Log::Log4perl->get_logger("ProbModelSEEDHelper");
	my $media = $self->get_object($params->{media},"media");
    if (!defined($media)) {
    	$self->error("Media retrieval failed!");
    }
    my $simptherm = 0;
    my $thermconst = 0;
    if ($params->{thermo_const_type} eq "Simple") {
    	$simptherm = 1;
    	$thermconst = 1;
    }
    my $fba = Bio::KBase::ObjectAPI::KBaseFBA::FBA->new({
		id => $params->{output_file},
		fva => $params->{fva},
		fluxMinimization => $params->{minimizeflux},
		findMinimalMedia => $params->{findminmedia},
		allReversible => $params->{allreversible},
		simpleThermoConstraints => $simptherm,
		thermodynamicConstraints => $thermconst,
		noErrorThermodynamicConstraints => 0,
		minimizeErrorThermodynamicConstraints => 1,
		maximizeObjective => 1,
		compoundflux_objterms => {},
    	reactionflux_objterms => {},
		biomassflux_objterms => {},
		comboDeletions => 0,
		numberOfSolutions => 1,
		objectiveConstraintFraction => $params->{objective_fraction},
		defaultMaxFlux => 1000,
		defaultMaxDrainFlux => 0,
		defaultMinDrainFlux => -1000,
		decomposeReversibleFlux => 0,
		decomposeReversibleDrainFlux => 0,
		fluxUseVariables => 0,
		drainfluxUseVariables => 0,
		fbamodel_ref => $model->_reference(),
		media_ref => $media->_reference(),
		geneKO_refs => [],
		reactionKO_refs => [],
		additionalCpd_refs => [],
		uptakeLimits => {},
		parameters => {},
		inputfiles => {},
		FBAConstraints => [],
		FBAReactionBounds => [],
		FBACompoundBounds => [],
		outputfiles => {},
		FBACompoundVariables => [],
		FBAReactionVariables => [],
		FBABiomassVariables => [],
		FBAPromResults => [],
		FBADeletionResults => [],
		FBAMinimalMediaResults => [],
		FBAMetaboliteProductionResults => [],
	});
	if ($params->{predict_essentiality} == 1) {
		$fba->{comboDeletions} = 1;
	}
	$fba->parent($self->PATRICStore());
	foreach my $term (@{$params->{objective}}) {
		if ($term->[0] eq "flux" || $term->[0] eq "reactionflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForReaction($term->[1]);
			if (!defined($obj)) {
				$self->error("Reaction ".$term->[1]." not found!");
			}
			$fba->reactionflux_objterms()->{$obj->id()} = $term->[2];
		} elsif ($term->[0] eq "compoundflux" || $term->[0] eq "drainflux") {
			$term->[0] = "drainflux";
			my $obj = $model->searchForCompound($term->[1]);
			if (!defined($obj)) {
				$self->error("Compound ".$term->[1]." not found!");
			}
			$fba->compoundflux_objterms()->{$obj->id()} = $term->[2];
		} elsif ($term->[0] eq "biomassflux") {
			my $obj = $model->searchForBiomass($term->[1]);
			if (!defined($obj)) {
				$self->error("Biomass ".$term->[1]." not found!");
			}
			$fba->biomassflux_objterms()->{$obj->id()} = $term->[2];
		} else {
			$self->error("Objective variable type ".$term->[0]." not recognized!");
		}
	}
	foreach my $term (@{$params->{custom_bounds}}) {
		if ($term->[0] eq "flux" || $term->[0] eq "reactionflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForReaction($term->[1]);
			if (!defined($obj)) {
				$self->error("Reaction ".$term->[1]." not found!");
			}
			$fba->add("FBAReactionBounds",{modelreaction_ref => $obj->_reference(),variableType=> $term->[0],upperBound => $term->[2],lowerBound => $term->[3]});
		} elsif ($term->[0] eq "compoundflux" || $term->[0] eq "drainflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForCompound($term->[1]);
			if (!defined($obj)) {
				$self->error("Compound ".$term->[1]." not found!");
			}
			$fba->add("FBACompoundBounds",{modelcompound_ref => $obj->_reference(),variableType=> $term->[0],upperBound => $term->[2],lowerBound => $term->[3]});
		} else {
			$self->error("Objective variable type ".$term->[0]." not recognized!");
		}
	}
	if (defined($model->genome_ref())) {
		my $genome = $model->genome();
		foreach my $gene (@{$params->{geneko}}) {
			my $geneObj = $genome->searchForFeature($gene);
			if (defined($geneObj)) {
				$fba->addLinkArrayItem("geneKOs",$geneObj);
			}
		}
	}
	foreach my $reaction (@{$params->{rxnko}}) {
		my $rxnObj = $model->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$fba->addLinkArrayItem("reactionKOs",$rxnObj);
		}
	}
	foreach my $compound (@{$params->{media_supplement}}) {
		my $cpdObj = $model->searchForCompound($compound);
		if (defined($cpdObj)) {
			$fba->addLinkArrayItem("additionalCpds",$cpdObj);
		}
	}
	if ($params->{probanno}) {
		# Will switch this to have get_object automatically convert to json.
		$log->info("Getting reaction likelihoods from ".$model->rxnprobs_ref());
		my $rxnprobs = $self->get_object($model->rxnprobs_ref(),undef,{refreshcache => 1});
	    if (!defined($rxnprobs)) {
	    	$self->error("Reaction likelihood retrieval from ".$model->rxnprobs_ref()." failed");
	    }		
		my $probrxns = Bio::KBase::ObjectAPI::utilities::FROMJSON($rxnprobs);
		$fba->{parameters}->{"Objective coefficient file"} = "ProbModelReactionCoefficients.txt";
		$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"} = [];
		my $rxncosts = {};
		for (my $i=0; $i < @{$probrxns}; $i++) {
			my $rxn = $probrxns->[$i];
			$rxncosts->{$rxn->[0]} = (1-$rxn->[1]);
		}
		my $compindecies = {};
		my $comps = $model->modelcompartments();
		for (my $i=0; $i < @{$comps}; $i++) {
			$compindecies->{$comps->[$i]->compartmentIndex()}->{$comps->[$i]->compartment()->id()} = 1;
		}
		foreach my $compindex (keys(%{$compindecies})) {
			my $tmp = $model->template();
			my $tmprxns = $tmp->templateReactions();
			for (my $i=0; $i < @{$tmprxns}; $i++) {
				my $tmprxn = $tmprxns->[$i];
				my $tmpid = $tmprxn->reaction()->id()."_".$tmprxn->compartment()->id().$compindex;
				if (defined($rxncosts->{$tmprxn->reaction()->id()})) {
					$log->info("adding rxn ".$tmpid." with cost ".$rxncosts->{$tmprxn->reaction()->id()});
					push(@{$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"}},"forward\t".$tmpid."\t".$rxncosts->{$tmprxn->reaction()->id()});
					push(@{$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"}},"reverse\t".$tmpid."\t".$rxncosts->{$tmprxn->reaction()->id()});
				}
			}
		}	
    	$log->info("Added reaction coefficients from reaction likelihoods in ".$model->rxnprobs_ref());
	}
	return $fba;
}
#****************************************************************************
#Probanno functions
#****************************************************************************


#****************************************************************************
#Non-APP API Call Implementations
#****************************************************************************
sub copy_genome {
	my($self,$input) = @_;
	$input = $self->validate_args($input,["genome"],{
    	destination => undef,
    	destname => undef,
		to_kbase => 0,
		workspace_url => undef,
		kbase_username => undef,
		kbase_password => undef,
		kbase_token => undef,
		plantseed => 0,
    });
    my $genome = $self->get_genome($input->{genome});
    if (!defined($input->{destination})) {
    	$input->{destination} = "/".$self->{_params}->{username}."/modelseed/genomes/";
    	if ($input->{plantseed} == 1) {
    		$input->{destination} = "/".$self->{_params}->{username}."/plantseed/genomes/";
    	}
    }
    if (!defined($input->{destname})) {
    	$input->{destname} = $genome->wsmeta()->[0];
    }
    if ($input->{destination}.$input->{destname} eq $input->{genome}) {
    	$self->error("Copy source and destination identical! Aborting!");
    }
    if (defined($self->get_model_meta($genome->wsmeta()->[2]."/.".$genome->wsmeta()->[0]))) {
    	$self->copy_object($genome->wsmeta()->[2]."/.".$genome->wsmeta()->[0],$input->{destination}.".".$input->{destname},1);
    }
    
    return $self->save_object($input->{destination}.$input->{destname},$genome,"genome");
}
sub copy_model {
	my($self,$input) = @_;
	$input = $self->validate_args($input,["model"],{
    	destination => undef,
		destname => undef,
		to_kbase => 0,
		copy_genome => 1,
		workspace_url => undef,
		kbase_username => undef,
		kbase_password => undef,
		kbase_token => undef,
		plantseed => 0,
    });
    my $model = $self->get_model($input->{model});
    if (!defined($input->{destination})) {
    	$input->{destination} = "/".$self->{_params}->{username}."/home/models/";
    	if ($input->{plantseed} == 1) {
    		$input->{destination} = "/".$self->{_params}->{username}."/plantseed/models/";
    	}
    }
    if (!defined($input->{destname})) {
    	$input->{destname} = $model->wsmeta()->[0];
    }
    if ($input->{destination}.$input->{destname} eq $input->{model}) {
    	$self->error("Copy source and destination identical! Aborting!");
    }
    if (defined($self->get_model_meta($model->wsmeta()->[2]."/.".$model->wsmeta()->[0]))) {
    	$self->copy_object($model->wsmeta()->[2]."/.".$model->wsmeta()->[0],$input->{destination}.".".$input->{destname},1);
    }
    if ($input->{copy_genome} == 1) {
    	$self->copy_genome({
    		genome => $model->genome_ref(),
    		plantseed => $input->{plantseed}
    	});
    	$model->genome_ref($model->genome()->_reference());
    }
    my $oldautometa = $model->wsmeta()->[8];
    my $meta = $self->save_object($input->{destination}.$input->{destname},$model,"model");
    $meta->[8] = $oldautometa;
    return $self->get_model_summary($meta);
}
#****************************************************************************
#Apps
#****************************************************************************
sub ComputeReactionProbabilities {
	my($self,$parameters) = @_;
    my $starttime = time();
    if (defined($parameters->{adminmode})) {
    	$self->{_params}->{adminmode} = $parameters->{adminmode}
    }
    $parameters = $self->validate_args($parameters,["genome","output_path"],{
    	output_file => undef
    });
    if (substr($parameters->{output_path},-1,1) ne "/") {
    	$parameters->{output_path} .= "/";
    }
	my $log = Log::Log4perl->get_logger("ProbModelSEEDHelper");
    $log->info("Started computing reaction probabilities for genome ".$parameters->{genome});
	if (!defined($parameters->{output_file})) {
		my $genome = $self->get_genome($parameters->{genome});
		$parameters->{output_file} = $genome->wsmeta()->[0].".rxnprobs";
	}
	my $rxnprobsref = $parameters->{output_path}.$parameters->{output_file};
    my $cmd = $ENV{KB_TOP}."/bin/ms-probanno ".$parameters->{genome}." ".$rxnprobsref." --token '".$self->token()."'";
    $log->info("Calculating reaction likelihoods with command: ".$cmd);
    system($cmd);
    if ($? != 0) {
    	$self->error("Calculating reaction likelihoods failed!");
    }
    # Waiting for workspace service to support rxnprobs type.
    # my $rxnprob = $self->get_object($rxnprobsref,"rxnprobs");
    my $data = $self->get_object($rxnprobsref,"unspecified"); # Replace with above line
    my $rxnprob = Bio::KBase::ObjectAPI::utilities::FROMJSON($data); # Delete this line
	$rxnprob->{jobresult} = {
	   	id => 0,
		app => {
			"id"=>"ComputeReactionProbabilities",
			"script"=>"App-ComputeReactionProbabilities",
			"label"=>"Compute reaction probabilities",
			"description"=>"Computes probabilities for reactions in model based on potential blast hits.",
			"parameters"=>[]
		},
		parameters => $parameters,
		start_time => $starttime,
		end_time => time(),
		elapsed_time => time()-$starttime,
		output_files => [[$parameters->{output_path}.$parameters->{output_file}]],
		job_output => "",
		hostname => "https://p3.theseed.org/services/ProbModelSEED"
	};
	return $self->save_object($parameters->{output_path}.$parameters->{output_file},$rxnprob,"unspecified"); # "rxnprobs" when workspace updated
}

sub ModelReconstruction {
	my($self,$parameters) = @_;
    my $starttime = time();
    if (defined($parameters->{adminmode})) {
    	$self->{_params}->{adminmode} = $parameters->{adminmode}
    }
    $parameters = $self->validate_args($parameters,[],{
    	media => undef,
    	template_model => undef,
    	fulldb => 0,
    	output_path => undef,
    	genome => undef,
    	output_file => undef,
    	gapfill => 1,
    	probannogapfill => 0,
    	probanno => 0,
    	predict_essentiality => 1,
    });

	my $log = Log::Log4perl->get_logger("ProbModelSEEDHelper");
    $log->info("Started model reconstruction for genome ".$parameters->{genome});
	
	my $genome = $self->get_genome($parameters->{genome});
    if (!defined($parameters->{output_file})) {
    	$parameters->{output_file} = $genome->id()."_model";	
    }
    if (!defined($parameters->{media})) {
		if ($genome->domain() eq "Plant" || $genome->taxonomy() =~ /viridiplantae/i) {
			$parameters->{media} = "/chenry/public/modelsupport/media/PlantHeterotrophicMedia";
		} else {
			$parameters->{media} = $self->{_params}->{default_media};
		}
	}
    
    my $template;
    if (!defined($parameters->{templatemodel})) {
    	if ($genome->domain() eq "Plant" || $genome->taxonomy() =~ /viridiplantae/i) {
    		if (!defined($parameters->{output_path})) {
    			$parameters->{output_path} = "/".$self->{_params}->{username}."/plantseed/models/";
    		}
    		$template = $self->get_object($self->{_params}->{template_dir}."plant.modeltemplate","modeltemplate");
    	} else {
    		if (!defined($parameters->{output_path})) {
    			$parameters->{output_path} = "/".$self->{_params}->{username}."/home/models/";
    		}
    		my $classifier_data = $self->get_object($self->{_params}->{classifier},"string");
    		my $class = $self->classify_genome($classifier_data,$genome);
    		if ($class eq "Gram positive") {
	    		$template = $self->get_object($self->{_params}->{template_dir}."GramPositive.modeltemplate","modeltemplate");
	    	} elsif ($class eq "Gram negative") {
	    		$template = $self->get_object($self->{_params}->{template_dir}."GramNegative.modeltemplate","modeltemplate");
	    	}
    	}
    } else {
    	$template = $self->get_object($parameters->{templatemodel},"modeltemplate");
    }
    if (!defined($template)) {
    	$self->error("template retrieval failed!");
    }
    if (substr($parameters->{output_path},-1,1) ne "/") {
    	$parameters->{output_path} .= "/";
    }
    my $folder = $parameters->{output_path}.".".$parameters->{output_file};
    my $outputfiles = [];
   	$self->save_object($folder,undef,"folder",{application_type => "ModelReconstruction"});
    #Only stash genome in model folder if it's not already a workspace genome (e.g. from RAST/PATRIC/KBase/SEED)
    if ($parameters->{genome} =~ m/^PATRICSOLR:(.+)$/ || $parameters->{genome} =~ m/^RAST:(.+)$/ || $parameters->{genome} =~ m/^PUBSEED:(.+)$/ || $parameters->{genome} =~ m/^KBASE:(.+)$/) {
    	$self->save_object($folder."/".$genome->id().".genome",$genome,"genome");
    }
    # Note, the save operation above will have updated the reference for the genome which must be done
    # before building the model.
    my $mdl = $template->buildModel({
	    genome => $genome,
	    modelid => $parameters->{output_file},
	    fulldb => $parameters->{fulldb}
	});
    #Now compute reaction probabilities if they are needed for gapfilling or probanno model building
    if ($parameters->{probanno} == 1 || ($parameters->{gapfill} == 1 && $parameters->{probannogapfill} == 1)) {
    	my $genomeref = $genome->_reference();
    	$genomeref =~ s/\|\|$//; # Remove the extraneous || at the end of the reference
    	$self->ComputeReactionProbabilities({
    		genome => $genomeref,
    		output_path => $folder,
    		output_file => $genome->id().".rxnprobs"
    	});
    }
    $mdl->jobresult({
    	id => 0,
		app => {
			"id"=>"ModelReconstruction",
			"script"=>"App-ModelReconstruction",
			"label"=>"Reconstruct metabolic model",
			"description"=>"Reconstructs a metabolic model from an annotated genome.",
			"parameters"=>[]
		},
		parameters => $parameters,
		start_time => $starttime,
		end_time => time(),
		elapsed_time => time()-$starttime,
		output_files => [[$parameters->{output_path}."/".$parameters->{output_file}]],
		job_output => "",
		hostname => "https://p3.theseed.org/services/ProbModelSEED"
    });
    $self->save_object($folder."/fba",undef,"folder");
    $self->save_object($folder."/gapfilling",undef,"folder");
    my $output = $self->save_object($parameters->{output_path}."/".$parameters->{output_file},$mdl,"model");
    if ($parameters->{gapfill} == 1) {
    	my $gfmeta = $self->GapfillModel({
    		model => $parameters->{output_path}."/".$parameters->{output_file},
    		media => $parameters->{media},
    		integrate_solution => 1,
    		probanno => $parameters->{probanno},
    		update_files => 0
    	});    	
    	if ($parameters->{predict_essentiality} == 1) {
    		Bio::KBase::ObjectAPI::utilities::set_global("gapfill name","");
    		$self->FluxBalanceAnalysis({
	    		model => $parameters->{output_path}."/".$parameters->{output_file},
	    		media => $parameters->{media},
	    		predict_essentiality => 1
	    	});
    	}	
    }
    $mdl = $self->get_model($parameters->{output_path}."/".$parameters->{output_file});
    $self->save_object($parameters->{output_path}."/.".$parameters->{output_file}."/".$parameters->{output_file}.".sbml",$mdl->export({format => "sbml"}),"string",{
	   description => "SBML version of model data for use in COBRA toolbox and other applications",
	   model => $parameters->{output_path}."/".$parameters->{output_file}
	});
	my $mdlcpds = $mdl->modelcompounds();
	my $cpdtbl = "ID\tName\tFormula\tCharge\tCompartment\n";
	for (my $i=0; $i < @{$mdlcpds}; $i++) {
		$cpdtbl .= $mdlcpds->[$i]->id()."\t".$mdlcpds->[$i]->name()."\t".$mdlcpds->[$i]->formula()."\t".$mdlcpds->[$i]->compound()->defaultCharge()."\t".$mdlcpds->[$i]->modelcompartment()->label()."\n";
	}
	print $parameters->{output_path}."/.".$parameters->{output_file}."/".$parameters->{output_file}.".cpdtbl\n";
	$self->save_object($parameters->{output_path}."/.".$parameters->{output_file}."/".$parameters->{output_file}.".cpdtbl",$cpdtbl,"string",{
	   description => "Tab delimited table containing data on compounds in metabolic model",
	   model => $parameters->{output_path}."/".$parameters->{output_file}
	});
	my $mdlrxns = $mdl->modelreactions();
	my $rxntbl = "ID\tName\tEquation\tDefinition\tGenes\n";
	for (my $i=0; $i < @{$mdlrxns}; $i++) {
		$rxntbl .= $mdlrxns->[$i]->id()."\t".$mdlrxns->[$i]->name()."\t".$mdlrxns->[$i]->equation()."\t".$mdlrxns->[$i]->definition()."\t".$mdlrxns->[$i]->gprString()."\n";
	}
	print $parameters->{output_path}."/.".$parameters->{output_file}."/".$parameters->{output_file}.".rxntbl\n";
	$self->save_object($parameters->{output_path}."/.".$parameters->{output_file}."/".$parameters->{output_file}.".rxntbl",$rxntbl,"string",{
	   description => "Tab delimited table containing data on reactions in metabolic model",
	   model => $parameters->{output_path}."/".$parameters->{output_file}
	});
    return $self->get_model_summary($output);
}

sub FluxBalanceAnalysis {
	my($self,$parameters) = @_;
    my $starttime = time();
    if (defined($parameters->{adminmode})) {
    	$self->{_params}->{adminmode} = $parameters->{adminmode}
    }
	$parameters = $self->validate_args($parameters,["model"],{
		media => undef,
		fva => 1,
		predict_essentiality => 0,
		minimizeflux => 1,
		findminmedia => 0,
		allreversible => 0,
		thermo_const_type => "None",
		media_supplement => [],
		geneko => [],
		rxnko => [],
		objective_fraction => 1,
		custom_bounds => [],
		objective => [["biomassflux","bio1",1]],
		custom_constraints => [],
		uptake_limits => [],
	});
	$parameters->{fva} = 1;
	$parameters->{minimizeflux} = 1;

	my $log = Log::Log4perl->get_logger("ProbModelSEEDHelper");
    $log->info("Started flux balance analysis for model ".$parameters->{model}." on media ".$parameters->{media});

    my $model = $self->get_model($parameters->{model});
    $parameters->{model} = $model->_reference();
    if (!defined($parameters->{media})) {
		if ($model->genome()->domain() eq "Plant" || $model->genome()->taxonomy() =~ /viridiplantae/i) {
			$parameters->{media} = "/chenry/public/modelsupport/media/PlantHeterotrophicMedia";
		} else {
			$parameters->{media} = $self->{_params}->{default_media};
		}
	}
    
    #Setting output path based on model and then creating results folder
    $parameters->{output_path} = $model->wsmeta()->[2].".".$model->wsmeta()->[0]."/fba";
    if (!defined($parameters->{output_file})) {
	    my $list = $self->workspace_service()->ls({
			paths => [$parameters->{output_path}],
			excludeDirectories => 1,
			excludeObjects => 0,
			recursive => 1,
			query => {type => "fba"}
		});
		my $index = 0;
		if (defined($list->{$parameters->{output_path}})) {
			$list = $list->{$parameters->{output_path}};
			$index = @{$list};
			for (my $i=0; $i < @{$list}; $i++) {
				if ($list->[$i]->[0] =~ /^fba\.(\d+)$/) {
					if ($1 > $index) {
						$index = $1+1;
					}
				}
			}
		}
		$parameters->{output_file} = "fba.".$index;
    }
    
    my $fba = $self->build_fba_object($model,$parameters);
    my $objective = $fba->runFBA();
    print "Objective:".$objective."\n";
    if (!defined($objective)) {
    	$self->error("FBA failed with no solution returned! See ".$fba->jobnode());
    }
    $fba->jobresult({
    	id => 0,
		app => {
			"id"=>"FluxBalanceAnalysis",
			"script"=>"App-FluxBalanceAnalysis",
			"label"=>"Run flux balance analysis",
			"description"=>"Run flux balance analysis on model.",
			"parameters"=>[]
		},
		parameters => $parameters,
		start_time => $starttime,
		end_time => time(),
		elapsed_time => time()-$starttime,
		output_files => [[ $parameters->{output_path}."/".$parameters->{output_file}]],
		job_output => "",
		hostname => "https://p3.theseed.org/services/ProbModelSEED",
    });
    #Printing essential gene list as feature group and text list
    my $fbatbl = "ID\tName\tEquation\tFlux\tUpper bound\tLower bound\tMax\tMin\n";
    my $objs = $fba->FBABiomassVariables();
    for (my $i=0; $i < @{$objs}; $i++) {
    	$fbatbl .= $objs->[$i]->biomass()->id()."\t".$objs->[$i]->biomass()->name()."\t".
    		$objs->[$i]->biomass()->definition()."\t".
    		$objs->[$i]->value()."\t".$objs->[$i]->upperBound()."\t".
    		$objs->[$i]->lowerBound()."\t".$objs->[$i]->max()."\t".
    		$objs->[$i]->min()."\t".$objs->[$i]->class()."\n";
    }
    $objs = $fba->FBAReactionVariables();
    for (my $i=0; $i < @{$objs}; $i++) {
    	$fbatbl .= $objs->[$i]->modelreaction()->id()."\t".$objs->[$i]->modelreaction()->name()."\t".
    		$objs->[$i]->modelreaction()->definition()."\t".
    		$objs->[$i]->value()."\t".$objs->[$i]->upperBound()."\t".
    		$objs->[$i]->lowerBound()."\t".$objs->[$i]->max()."\t".
    		$objs->[$i]->min()."\t".$objs->[$i]->class()."\n";
    }
    $objs = $fba->FBACompoundVariables();
    for (my $i=0; $i < @{$objs}; $i++) {
    	$fbatbl .= $objs->[$i]->modelcompound()->id()."\t".$objs->[$i]->modelcompound()->name()."\t".
    		"=> ".$objs->[$i]->modelcompound()->name()."[e]\t".
    		$objs->[$i]->value()."\t".$objs->[$i]->upperBound()."\t".
    		$objs->[$i]->lowerBound()."\t".$objs->[$i]->max()."\t".
    		$objs->[$i]->min()."\t".$objs->[$i]->class()."\n";
    } 
    $self->save_object($parameters->{output_path}."/".$parameters->{output_file}.".fluxtbl",$fbatbl,"string",{
	   description => "Tab delimited table containing data on reaction fluxes from flux balance analysis",
	   fba => $parameters->{output_file},
	   media => $parameters->{media},
	   model => $parameters->{model}
	});
    if ($parameters->{predict_essentiality} == 1) {
	    my $esslist = [];
	    my $ftrlist = [];
	    my $delresults = $fba->FBADeletionResults();
	    for (my $i=0; $i < @{$delresults}; $i++) {
	    	if ($delresults->[$i]->growthFraction < 0.00001) {
	    		my $ftrs =  $delresults->[$i]->features();
	    		my $aliases = $ftrs->[0]->aliases();
	    		my $ftrid;
	    		for (my $j=0; $j < @{$aliases}; $j++) {
	    		 	if ($aliases->[$j] =~ m/^PATRIC\./) {
	    		 		$ftrid = $aliases->[$j];
	    		 		last;
	    		 	}
	    		}
	    		if (!defined($ftrid)) {
	    			$ftrid = $ftrs->[0]->id();
	    		}
	    		push(@{$ftrlist},$ftrid);
	    		push(@{$esslist},$ftrs->[0]->id());
	    	}
	    }
	   	$self->save_object($model->wsmeta()->[2].".".$model->wsmeta()->[0]."/essentialgenes/".$parameters->{output_file}."-essentials",join("\n",@{$esslist}),"string",{
	    	description => "Tab delimited table containing list of predicted genes from flux balance analysis",
	    	media => $parameters->{media},
	    	model => $parameters->{model}
	    });
	    my $ftrgroup = {
	    	id_list => {
	    		feature_id => $ftrlist
	    	},
	    	name => $model->wsmeta()->[0]."-".$fba->media()->wsmeta()->[0]."-essentials"
	    };
	    $self->save_object("/".$self->{_params}->{username}."/home/Feature Groups/".$model->wsmeta()->[0]."-".$fba->media()->wsmeta()->[0]."-essentials",$ftrgroup,"feature_group",{
	    	description => "Group of essential genes predicted by metabolic models",
	    	media => $parameters->{media},
	    	model => $parameters->{model}
	    });
    }
    return $self->save_object($parameters->{output_path}."/".$parameters->{output_file},$fba,"fba",{
    	objective => $objective,
    	media => $parameters->{media}
    });
}

sub GapfillModel {
	my($self,$parameters) = @_;
	my $starttime = time();
    if (defined($parameters->{adminmode})) {
    	$self->{_params}->{adminmode} = $parameters->{adminmode}
    }
    $parameters = $self->validate_args($parameters,["model"],{
		media => undef,
		probanno => 0,
		alpha => 0,
		allreversible => 0,
		thermo_const_type => "None",
		media_supplement => [],
		geneko => [],
		rxnko => [],
		objective_fraction => 0.001,
		uptake_limits => [],
		custom_bounds => [],
		objective => [["biomassflux","bio1",1]],
		custom_constraints => [],
		low_expression_theshold => 0.5,
		high_expression_theshold => 0.5,
		target_reactions => [],
		completeGapfill => 0,
		solver => undef,
		omega => 0,
		allowunbalanced => 0,
		blacklistedrxns => [],
		gauranteedrxns => [],
		exp_raw_data => {},
		source_model => undef,
		integrate_solution => 0,
		fva => 0,
		minimizeflux => 0,
		findminmedia => 0,
		update_files => 1
	});
	my $log = Log::Log4perl->get_logger("ProbModelSEEDHelper");
    $log->info("Starting gap fill for model ".$parameters->{model}." on media ".$parameters->{media});
	
    if (defined($parameters->{adminmode}) && $parameters->{adminmode} == 1) {
    	$self->adminmode($parameters->{adminmode});
    }
    my $model = $self->get_model($parameters->{model});
    $parameters->{model} = $model->_reference();
    if (!defined($parameters->{media})) {
		if ($model->genome()->domain() eq "Plant" || $model->genome()->taxonomy() =~ /viridiplantae/i) {
			$parameters->{media} = "/chenry/public/modelsupport/media/PlantHeterotrophicMedia";
		} else {
			$parameters->{media} = $self->{_params}->{default_media};
		}
	}
    
    #Setting output path based on model and then creating results folder
    $parameters->{output_path} = $model->wsmeta()->[2].".".$model->wsmeta()->[0]."/gapfilling";
    if (!defined($parameters->{output_file})) {
	    my $gflist = $self->workspace_service()->ls({
			adminmode => $self->adminmode(),
			paths => [$parameters->{output_path}],
			excludeDirectories => 1,
			excludeObjects => 0,
			recursive => 1,
			query => {type => "fba"}
		});
		my $index = 0;
		if (defined($gflist->{$parameters->{output_path}})) {
			$gflist = $gflist->{$parameters->{output_path}};
			$index = @{$gflist};
			for (my $i=0; $i < @{$gflist}; $i++) {
				if ($gflist->[$i]->[0] =~ /^gf\.(\d+)$/) {
					if ($1 > $index) {
						$index = $1+1;
					}
				}
			}
		}
		$parameters->{output_file} = "gf.".$index;
    }
    Bio::KBase::ObjectAPI::utilities::set_global("gapfill name",$parameters->{output_file});
    
    if (defined($parameters->{source_model})) {
		$parameters->{source_model} = $self->get_model($parameters->{source_model});
    }
    
    my $fba = $self->build_fba_object($model,$parameters);
    $fba->PrepareForGapfilling($parameters);
    my $objective = $fba->runFBA();
    $fba->parseGapfillingOutput();
    if (!defined($fba->gapfillingSolutions()->[0])) {
		$self->error("Analysis completed, but no valid solutions found!");
	}
	if (@{$fba->gapfillingSolutions()->[0]->gapfillingSolutionReactions()} == 0) {
		$self->error("No gapfilling needed on specified condition!");
	}
	my $gfsols = [];
	my $gftbl = "Solution\tID\tName\tEquation\tDirection\n";
	for (my $i=0; $i < @{$fba->gapfillingSolutions()}; $i++) {
		for (my $j=0; $j < @{$fba->gapfillingSolutions()->[$i]->gapfillingSolutionReactions()}; $j++) {
			my $rxn = $fba->gapfillingSolutions()->[$i]->gapfillingSolutionReactions()->[$j];
			$gftbl .= $i."\t".$rxn->reaction()->id()."\t".$rxn->reaction()->name()."\t".
    		$rxn->reaction()->definition()."\t".$rxn->direction()."\n";
			$gfsols->[$i]->[$j] = $fba->gapfillingSolutions()->[$i]->gapfillingSolutionReactions()->[$j]->serializeToDB();
		}
	}
	$self->save_object($parameters->{output_path}."/".$parameters->{output_file}.".gftbl",$gftbl,"string",{
	   description => "Tab delimited table of reactions gapfilled in metabolic model",
	   fba => $parameters->{output_file},
	   media => $parameters->{media},
	   model => $parameters->{model}
	});
	my $solutiondata = Bio::KBase::ObjectAPI::utilities::TOJSON($gfsols);
	my $fbatbl = "ID\tName\tEquation\tFlux\tUpper bound\tLower bound\tMax\tMin\n";
    my $objs = $fba->FBABiomassVariables();
    for (my $i=0; $i < @{$objs}; $i++) {
    	$fbatbl .= $objs->[$i]->biomass()->id()."\t".$objs->[$i]->biomass()->name()."\t".
    		$objs->[$i]->biomass()->definition()."\t".
    		$objs->[$i]->value()."\t".$objs->[$i]->upperBound()."\t".
    		$objs->[$i]->lowerBound()."\t".$objs->[$i]->max()."\t".
    		$objs->[$i]->min()."\t".$objs->[$i]->class()."\n";
    }
    $objs = $fba->FBAReactionVariables();
    for (my $i=0; $i < @{$objs}; $i++) {
    	$fbatbl .= $objs->[$i]->modelreaction()->id()."\t".$objs->[$i]->modelreaction()->name()."\t".
    		$objs->[$i]->modelreaction()->definition()."\t".
    		$objs->[$i]->value()."\t".$objs->[$i]->upperBound()."\t".
    		$objs->[$i]->lowerBound()."\t".$objs->[$i]->max()."\t".
    		$objs->[$i]->min()."\t".$objs->[$i]->class()."\n";
    }
    $objs = $fba->FBACompoundVariables();
    for (my $i=0; $i < @{$objs}; $i++) {
    	$fbatbl .= $objs->[$i]->modelcompound()->id()."\t".$objs->[$i]->modelcompound()->name()."\t".
    		"=> ".$objs->[$i]->modelcompound()->name()."[e]\t".
    		$objs->[$i]->value()."\t".$objs->[$i]->upperBound()."\t".
    		$objs->[$i]->lowerBound()."\t".$objs->[$i]->max()."\t".
    		$objs->[$i]->min()."\t".$objs->[$i]->class()."\n";
    } 
    $self->save_object($parameters->{output_path}."/".$parameters->{output_file}.".fbatbl",$fbatbl,"string",{
	   description => "Table of fluxes through reactions used in gapfilling solution",
	   fba => $parameters->{output_file},
	   media => $parameters->{media},
	   model => $parameters->{model}
	});
	$fba->jobresult({
    	id => 0,
		app => {
			"id"=>"GapfillModel",
			"script"=>"App-GapfillModel",
			"label"=>"Gapfill metabolic model",
			"description"=>"Run gapfilling on model.",
			"parameters"=>[]
		},
		parameters => $parameters,
		start_time => $starttime,
		end_time => time(),
		elapsed_time => time()-$starttime,
		output_files => [[ $parameters->{output_path}."/".$parameters->{output_file}]],
		job_output => "",
		hostname => "https://p3.theseed.org/services/ProbModelSEED",
    });
    if ($parameters->{update_files} == 1) {
    	my $report = $model->integrateGapfillSolutionFromObject({
			gapfill => $fba
		});
    	$self->save_object($model->wsmeta()->[2]."/.".$model->wsmeta()->[0]."/".$model->wsmeta()->[0].".sbml",$model->export({format => "sbml"}),"string",{
		   description => "SBML version of model data for use in COBRA toolbox and other applications",
		   model => $model->wsmeta()->[2]."/".$model->wsmeta()->[0]
		});
		my $mdlcpds = $model->modelcompounds();
		my $cpdtbl = "ID\tName\tFormula\tCharge\tCompartment\n";
		for (my $i=0; $i < @{$mdlcpds}; $i++) {
			$cpdtbl .= $mdlcpds->[$i]->id()."\t".$mdlcpds->[$i]->name()."\t".$mdlcpds->[$i]->formula()."\t".$mdlcpds->[$i]->compound()->defaultCharge()."\t".$mdlcpds->[$i]->modelcompartment()->label()."\n";
		}
		print $model->wsmeta()->[2]."/.".$model->wsmeta()->[0]."/".$model->wsmeta()->[0].".cpdtbl\n";
		$self->save_object($model->wsmeta()->[2]."/.".$model->wsmeta()->[0]."/".$model->wsmeta()->[0].".cpdtbl",$cpdtbl,"string",{
		   description => "Tab delimited table containing data on compounds in metabolic model",
		   model => $model->wsmeta()->[2]."/".$model->wsmeta()->[0]
		});
		my $mdlrxns = $model->modelreactions();
		my $rxntbl = "ID\tName\tEquation\tDefinition\tGenes\n";
		for (my $i=0; $i < @{$mdlrxns}; $i++) {
			$rxntbl .= $mdlrxns->[$i]->id()."\t".$mdlrxns->[$i]->name()."\t".$mdlrxns->[$i]->equation()."\t".$mdlrxns->[$i]->definition()."\t".$mdlrxns->[$i]->gprString()."\n";
		}
		print $model->wsmeta()->[2]."/.".$model->wsmeta()->[0]."/".$model->wsmeta()->[0].".rxntbl\n";
		$self->save_object($model->wsmeta()->[2]."/.".$model->wsmeta()->[0]."/".$model->wsmeta()->[0].".rxntbl",$rxntbl,"string",{
		   description => "Tab delimited table containing data on reactions in metabolic model",
		   model => $model->wsmeta()->[2]."/".$model->wsmeta()->[0]
		});
    }
    
    Bio::KBase::ObjectAPI::utilities::set_global("gapfill name","");
	return $self->get_model_summary($self->save_object($parameters->{output_path}."/".$parameters->{output_file},$fba,"fba",{
		integrated_solution => 0,
		solutiondata => $solutiondata,
		integratedindex => 0,
		media => $parameters->{media},
		integrated => $parameters->{integrate_solution}
	}));
}

sub load_to_shock {
	my($self,$data) = @_;
	my $uuid = Data::UUID->new()->create_str();
	File::Path::mkpath Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY();
	my $filename = Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY().$uuid;
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($filename,[$data]);
	my $output = Bio::KBase::ObjectAPI::utilities::runexecutable("curl -H \"Authorization: OAuth ".$self->token()."\" -X POST -F 'upload=\@".$filename."' ".$self->shock_url()."/node");
	$output = Bio::KBase::ObjectAPI::utilities::FROMJSON(join("\n",@{$output}));
	return $self->shock_url()."/node/".$output->{data}->{id};
}

#****************************************************************************
#Constructor
#****************************************************************************
sub new {
    my($class, $parameters) = @_;
    my $self = {};
    bless $self, $class;
    $parameters = $self->validate_args($parameters,["token","username","fbajobcache","fbajobdir","mfatoolkitbin",],{
    	data_api_url => "https://www.patricbrc.org/api/",
    	"workspace-url" => "http://p3.theseed.org/services/Workspace",
    	"shock-url" => "http://p3.theseed.org/services/shock_api",
    	adminmode => 0,
    	method => "unknown",
    	run_as_app => 0,
    	file_cache => "/disks/p3/fba/filecache/",
    	cache_targets => ["/chenry/public/modelsupport/biochemistry/default.biochem"],
    	biochemistry => "/chenry/public/modelsupport/biochemistry/default.biochem",
    	default_media => "/chenry/public/modelsupport/patric-media/Complete",
    	classifier => "/chenry/public/modelsupport/classifiers/gramclassifier.string",
    	template_dir => "/chenry/public/modelsupport/templates/"
    });
    $self->{_params} = $parameters;
    if ($self->{_params}->{fbajobcache} ne "none") {
    	Bio::KBase::ObjectAPI::utilities::FinalJobCache($self->{_params}->{fbajobcache});
    }
    Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY($self->{_params}->{fbajobdir});
    Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_BINARY($self->{_params}->{mfatoolkitbin});
    if (!-e Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY()."/ProbModelSEED.conf") {
    	if (!-d Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY()) {
    		File::Path::mkpath (Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY());
    	}
    	Bio::KBase::ObjectAPI::utilities::PRINTFILE(Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY()."/ProbModelSEED.conf",[
	    	"############################################################",
			"# A simple root logger with a Log::Log4perl::Appender::File ",
			"# file appender in Perl.",
			"############################################################",
			"log4perl.rootLogger=ERROR, LOGFILE",
			"",
			"log4perl.appender.LOGFILE=Log::Log4perl::Appender::File",
			"log4perl.appender.LOGFILE.filename=".Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY()."/ProbModelSEED.log",
			"log4perl.appender.LOGFILE.mode=append",
			"",
			"log4perl.appender.LOGFILE.layout=PatternLayout",
			"log4perl.appender.LOGFILE.layout.ConversionPattern=[%r] %F %L %c - %m%n",
    	]);
    }
    Log::Log4perl::init(Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY()."/ProbModelSEED.conf");
    return $self;
}

1;
