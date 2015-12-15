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
use Bio::KBase::ObjectAPI::logging;
use Bio::KBase::ObjectAPI::PATRICStore;
use Bio::ModelSEED::Client::SAP;
use Bio::KBase::AppService::Client;
use Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportClient;

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
		adminmode => Bio::KBase::ObjectAPI::config::adminmode(),
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
sub save_model {
	my($self,$model,$ref,$meta,$write_files) = @_;
	$self->save_object($ref,$model,"model",$meta);
	my $summary = $self->get_model_summary($model);
	if ($write_files == 1) {
		$self->save_object($model->wsmeta()->[2]."/.".$model->wsmeta()->[0]."/".$model->wsmeta()->[0].".sbml",$model->export({format => "sbml"}),"string",{
		   description => "SBML version of model data for use in COBRA toolbox and other applications",
		   model => $model->wsmeta()->[2]."/".$model->wsmeta()->[0]
		});
		my $mdlcpds = $model->modelcompounds();
		my $cpdtbl = "ID\tName\tFormula\tCharge\tCompartment\n";
		for (my $i=0; $i < @{$mdlcpds}; $i++) {
			$cpdtbl .= $mdlcpds->[$i]->id()."\t".$mdlcpds->[$i]->name()."\t".$mdlcpds->[$i]->formula()."\t".$mdlcpds->[$i]->compound()->defaultCharge()."\t".$mdlcpds->[$i]->modelcompartment()->label()."\n";
		}
		$self->save_object($model->wsmeta()->[2]."/.".$model->wsmeta()->[0]."/".$model->wsmeta()->[0].".cpdtbl",$cpdtbl,"string",{
		   description => "Tab delimited table containing data on compounds in metabolic model",
		   model => $model->wsmeta()->[2]."/".$model->wsmeta()->[0]
		});
		my $mdlrxns = $model->modelreactions();
		my $rxntbl = "ID\tName\tEquation\tDefinition\tGenes\n";
		for (my $i=0; $i < @{$mdlrxns}; $i++) {
			$rxntbl .= $mdlrxns->[$i]->id()."\t".$mdlrxns->[$i]->name()."\t".$mdlrxns->[$i]->equation()."\t".$mdlrxns->[$i]->definition()."\t".$mdlrxns->[$i]->gprString()."\n";
		}
		$self->save_object($model->wsmeta()->[2]."/.".$model->wsmeta()->[0]."/".$model->wsmeta()->[0].".rxntbl",$rxntbl,"string",{
		   description => "Tab delimited table containing data on reactions in metabolic model",
		   model => $model->wsmeta()->[2]."/".$model->wsmeta()->[0]
		});
	}
	return $summary;
}
sub get_genome {
	my($self, $ref) = @_;
	my $obj;
	if ($ref =~ m/^PATRIC:(.+)/) {
    	return $self->retrieve_PATRIC_genome($1);
	} elsif ($ref =~ m/^REFSEQ:(.+)/) {
    	return $self->retrieve_PATRIC_genome($1,1);
	} elsif ($ref =~ m/^PUBSEED:(.+)/) {
    	return $self->retrieve_SEED_genome($1);
	} elsif ($ref =~ m/^RAST:(.+)/) {
    	return $self->retrieve_RAST_genome($1);
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
		adminmode => Bio::KBase::ObjectAPI::config::adminmode()
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
		$self->PATRICStore()->cache()->{Bio::KBase::ObjectAPI::config::biochemistry()}->[0] = $bio->wsmeta();
		$self->PATRICStore()->cache()->{Bio::KBase::ObjectAPI::config::biochemistry()}->[1] = $bio;
	}
	if (!defined($self->{_cached_biochemistry})) {
		$self->{_cached_biochemistry} = $self->get_object(Bio::KBase::ObjectAPI::config::biochemistry(),"biochemistry");		
	}
	return $self->{_cached_biochemistry};
}

sub workspace_service {
	my($self) = @_;
	if (!defined($self->{_workspace_service})) {
		$self->{_workspace_service} = Bio::P3::Workspace::WorkspaceClientExt->new(Bio::KBase::ObjectAPI::config::workspace_url(),token => Bio::KBase::ObjectAPI::config::token());
	}
	return $self->{_workspace_service};
}
sub app_service {
	my($self) = @_;
	if (!defined($self->{_app_service})) {
		$self->{_app_service} = Bio::KBase::AppService::Client->new(Bio::KBase::ObjectAPI::config::appservice_url(),token => Bio::KBase::ObjectAPI::config::token());
	}
	return $self->{_app_service};
}
sub PATRICStore {
	my($self) = @_;
	if (!defined($self->{_PATRICStore})) {
		my $cachetarg = {};
		for (my $i=0; $i < @{Bio::KBase::ObjectAPI::config::cache_targets()}; $i++) {
			$cachetarg->{Bio::KBase::ObjectAPI::config::cache_targets()->[$i]} = 1;
		}
		$self->{_PATRICStore} = Bio::KBase::ObjectAPI::PATRICStore->new({
			data_api_url => Bio::KBase::ObjectAPI::config::data_api_url(),
			workspace => $self->workspace_service(),
			adminmode => Bio::KBase::ObjectAPI::config::adminmode(),
			file_cache => Bio::KBase::ObjectAPI::config::file_cache(),
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
		adminmode => Bio::KBase::ObjectAPI::config::adminmode()
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
	my ($self,$model) = @_;
	my $modelmeta = $model->wsmeta();
	my $numcpds = @{$model->modelcompounds()};
	my $numrxns = @{$model->modelreactions()};
	my $numcomps = @{$model->modelcompartments()};
	my $numbio = @{$model->biomasses()};
	my $output = {
		id => $modelmeta->[0],
		source => $model->source(),
		source_id => $modelmeta->[0],
		name => $model->name(),
		type => $model->type(),
		genome_ref => $model->genome_ref(),
		template_ref => $model->template_ref(),
		num_compounds => $numcpds,
		num_reactions => $numrxns,
		num_compartments => $numcomps,
		num_biomasses => $numbio,
		num_genes => $model->gene_count(),
		rundate => $modelmeta->[3],
		"ref" => $modelmeta->[2].$modelmeta->[0],
		gene_associated_reactions => $model->gene_associated_reaction_count(),
		gapfilled_reactions => $model->gapfilled_reaction_count(),
		fba_count => 0,
		num_biomass_compounds => $model->biomass_compound_count(),
		integrated_gapfills => $model->integrated_gapfill_count(),
		unintegrated_gapfills => $model->unintegrated_gapfill_count()
	};
	$output->{genome_ref} =~ s/\|\|//;
	$output->{template_ref} =~ s/\|\|//;
	my $list = $self->workspace_service()->ls({
		adminmode => Bio::KBase::ObjectAPI::config::adminmode(),
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
	my ($self,$genomeid,$refseq) = @_;
	#Retrieving genome information
	my $data = Bio::KBase::ObjectAPI::utilities::rest_download({url => Bio::KBase::ObjectAPI::config::data_api_url()."genome/?genome_id=".$genomeid."&http_accept=application/json",token => Bio::KBase::ObjectAPI::config::token()});
	if (!defined($refseq)) {
		$refseq = 0;
	}
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
		Bio::KBase::ObjectAPI::config::data_api_url()."genome/?genome_id=".$genomeid."&http_accept=application/json",
		$data->{completion_date},
		$genomeid,
		$data->{owner},
		$data->{genome_length},
		{},
		{},
		$uperm,
		$perm
    ];
    my $genomesource = "PATRIC";
    if ($refseq == 1) {
    	$genomesource = "RefSeq";
    }
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
		source => $genomesource,
		source_id => $genomeid,
		md5 => "none",
		taxonomy => join(":",@{$data->{taxon_lineage_names}}),
		gc_content => $data->{gc_content},
		complete => 1,
		publications => [$data->{publication}],
		features => [],
		contigset_ref => "",
	};
	#Retrieving feature information
	my $start = 0;
	my $params = {};
	my $loopcount = 0;
	my $ftrcount = 0;
	while ($start >= 0 && $loopcount < 100) {
		$loopcount++;#Insurance that no matter what, this loop won't run for more than 100 iterations
		my $ftrdata = Bio::KBase::ObjectAPI::utilities::rest_download({url => Bio::KBase::ObjectAPI::config::data_api_url()."genome_feature/?genome_id=".$genomeid."&http_accept=application/json&limit(10000,$start)",token => Bio::KBase::ObjectAPI::config::token()},$params);
		if (defined($ftrdata) && @{$ftrdata} > 0) {
			my $currentcount = @{$ftrdata};
			$ftrcount += $currentcount;
			for (my $i=0; $i < @{$ftrdata}; $i++) {
				$data = $ftrdata->[$i];
				if (($data->{feature_id} =~ m/^PATRIC/ && $refseq == 0) || ($data->{feature_id} =~ m/^RefSeq/ && $refseq == 1)) {
					my $id;
					if ($refseq == 1) {
						$id = $data->{refseq_locus_tag};
					} else {
						$id = $data->{patric_id};
					}
					if (defined($id)) {
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
			}
		}
		if ($ftrcount < $params->{count}) {
			$start = $ftrcount;
		} else {
			$start = -1;
		}
	}
	my $genome = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genome);
	$genome->wsmeta($meta);
	if ($refseq == 1) {
		$genome->_reference("REFSEQ:".$genomeid);
	} else {
		$genome->_reference("PATRIC:".$genomeid);
	}
	$genome->parent($self->PATRICStore());
	return $genome;
}
=head3 retrieve_SEED_genome
Definition:
	Genome = $self->retrieve_SEED_genome(string genome);
Description:
	Returns typed object for genome in SEED reference database
		
=cut
sub retrieve_SEED_genome {
	my($self,$id) = @_;
	my $sapsvr = Bio::ModelSEED::Client::SAP->new();
	my $data = $sapsvr->genome_data({
		-ids => [$id],
		-data => [qw(gc-content dna-size name taxonomy domain genetic-code)]
	});
	if (!defined($data->{$id})) {
    	$self->error("PubSEED genome ".$id." not found!");
    }
    my $genomeObj = {
		id => $id,
		scientific_name => $data->{$id}->[2],
		domain => $data->{$id}->[4],
		genetic_code => $data->{$id}->[5],
		dna_size => $data->{$id}->[1],
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "PubSEED",
		source_id => $id,
		taxonomy => $data->{$id}->[3],
		gc_content => $data->{$id}->[0]/100,
		complete => 1,
		publications => [],
		features => [],
    };
    my $contigset = {
		name => $genomeObj->{scientific_name},
		source_id => $genomeObj->{source_id},
		source => $genomeObj->{source},
		type => "Organism",
		contigs => []
    };
	my $featureHash = $sapsvr->all_features({-ids => $id});
	my $genomeHash = $sapsvr->genome_contigs({
		-ids => [$id]
	});
	my $featureList = $featureHash->{$id};
	my $contigList = $genomeHash->{$id};
	my $functions = $sapsvr->ids_to_functions({-ids => $featureList});
	my $locations = $sapsvr->fid_locations({-ids => $featureList});
	my $sequences = $sapsvr->fids_to_proteins({-ids => $featureList,-sequence => 1});
	my $contigHash = $sapsvr->contig_sequences({
		-ids => $contigList
	});
	foreach my $key (keys(%{$contigHash})) {
		$genomeObj->{num_contigs}++;
		push(@{$genomeObj->{contig_ids}},$key);
		push(@{$genomeObj->{contig_lengths}},length($contigHash->{$key}));
		push(@{$contigset->{contigs}},{
			id => $key,
			"length" => length($contigHash->{$key}),
			md5 => Digest::MD5::md5_hex($contigHash->{$key}),
			sequence => $contigHash->{$key},
			name => $key
		});
	}
	my $sortedcontigs = [sort { $a->{sequence} cmp $b->{sequence} } @{$contigset->{contigs}}];
	my $str = "";
	for (my $i=0; $i < @{$sortedcontigs}; $i++) {
		if (length($str) > 0) {
			$str .= ";";
		}
		$str .= $sortedcontigs->[$i]->{sequence};	
	}
	$genomeObj->{md5} = Digest::MD5::md5_hex($str);
	$contigset->{md5} = $genomeObj->{md5};
	$contigset->{id} = $id.".contigs";
	for (my $i=0; $i < @{$featureList}; $i++) {
		my $feature = {
  			id => $featureList->[$i],
			type => "peg",
			publications => [],
			subsystems => [],
			protein_families => [],
			aliases => [],
			annotations => [],
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => []
  		};
  		if ($featureList->[$i] =~ m/\.([^\.]+)\.\d+$/) {
  			$feature->{type} = $1;
  		}
		if (defined($functions->{$featureList->[$i]})) {
			$feature->{function} = $functions->{$featureList->[$i]};
		}
		if (defined($sequences->{$featureList->[$i]})) {
			$feature->{protein_translation} = $sequences->{$featureList->[$i]};
			$feature->{protein_translation_length} = length($feature->{protein_translation});
  			$feature->{dna_sequence_length} = 3*$feature->{protein_translation_length};
  			$feature->{md5} = Digest::MD5::md5_hex($feature->{protein_translation});
		}
  		if (defined($locations->{$featureList->[$i]}->[0])) {
			for (my $j=0; $j < @{$locations->{$featureList->[$i]}}; $j++) {
				my $loc = $locations->{$featureList->[$i]}->[$j];
				if ($loc =~ m/^(.+)_(\d+)([\+\-])(\d+)$/) {
					my $array = [split(/:/,$1)];
					if ($3 eq "-" || $3 eq "+") {
						$feature->{location}->[$j] = [$array->[1],$2,$3,$4];
					} elsif ($2 > $4) {
						$feature->{location}->[$j] = [$array->[1],$2,"-",($2-$4)];
					} else {
						$feature->{location}->[$j] = [$array->[1],$2,"+",($4-$2)];
					}
					$feature->{location}->[$j]->[1] = $feature->{location}->[$j]->[1]+0;
					$feature->{location}->[$j]->[3] = $feature->{location}->[$j]->[3]+0;
				}
			}
			
		}
  		push(@{$genomeObj->{features}},$feature);	
	}
	my $ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($contigset);
	$genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	$genomeObj->contigs($ContigObj);
	return $genomeObj;
}
=head3 retrieve_RAST_genome

Definition:
	Genome = $self->retrieve_RAST_genome(string genome);
Description:
	Returns typed object for genome in RAST reference database
		
=cut
sub retrieve_RAST_genome {
	my($self,$id,$username,$password) = @_;
	my $mssvr = Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportClient->new(Bio::KBase::ObjectAPI::config::mssserver_url());
	$mssvr->{token} = Bio::KBase::ObjectAPI::config::token();
	$mssvr->{client}->{token} = Bio::KBase::ObjectAPI::config::token();
	my $data = $mssvr->getRastGenomeData({
		genome => $id,
		username => $username,
		password => $password,
		getSequences => 1,
		getDNASequence => 1
	});
    if (!defined($data->{owner})) {
    	$self->_error("RAST genome ".$id." not found!",'get_genomeobject');
    }
	my $genomeObj = {
		id => $id,
		scientific_name => $data->{name},
		domain => $data->{taxonomy},
		genetic_code => 11,
		dna_size => $data->{size},
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "RAST",
		source_id => $id,
		taxonomy => $data->{taxonomy},
		gc_content => 0.5,
		complete => 1,
		publications => [],
		features => [],
    };
    my $contigset = {
		name => $genomeObj->{scientific_name},
		source_id => $genomeObj->{source_id},
		source => $genomeObj->{source},
		type => "Organism",
		contigs => []
    };
    my $contighash = {};
	for (my $i=0; $i < @{$data->{features}}; $i++) {
		my $ftr = $data->{features}->[$i];
		my $feature = {
  			id => $ftr->{ID}->[0],
			type => "peg",
			publications => [],
			subsystems => [],
			protein_families => [],
			aliases => [],
			annotations => [],
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => [],
			protein_translation_length => 0,
			protein_translation => "",
			dna_sequence_length => 0,
			md5 => ""
  		};
  		if ($ftr->{ID}->[0] =~ m/\.([^\.]+)\.\d+$/) {
  			$feature->{type} = $1;
  		}
  		if (defined($ftr->{SEQUENCE})) {
			$feature->{protein_translation} = $ftr->{SEQUENCE}->[0];
			$feature->{protein_translation_length} = length($feature->{protein_translation});
  			$feature->{dna_sequence_length} = 3*$feature->{protein_translation_length};
  			$feature->{md5} = Digest::MD5::md5_hex($feature->{protein_translation});
		}
		if (defined($ftr->{ROLES})) {
			$feature->{function} = join(" / ",@{$ftr->{ROLES}});
		}
  		if (defined($ftr->{LOCATION}->[0]) && $ftr->{LOCATION}->[0] =~ m/^(.+)_(\d+)([\+\-_])(\d+)$/) {
			my $contigData = $1;
			if (!defined($contighash->{$contigData})) {
				$contighash->{$contigData} = $2;
			} elsif ($2 > $contighash->{$contigData}) {
				$contighash->{$contigData} = $2;
			}
			if ($3 eq "-" || $3 eq "+") {
				$feature->{location} = [[$contigData,$2,$3,$4]];
			} elsif ($2 > $4) {
				$feature->{location} = [[$contigData,$2,"-",($2-$4)]];
			} else {
				$feature->{location} = [[$contigData,$2,"+",($4-$2)]];
			}
			$feature->{location}->[0]->[1] = $feature->{location}->[0]->[1]+0;
			$feature->{location}->[0]->[3] = $feature->{location}->[0]->[3]+0;
		}
  		push(@{$genomeObj->{features}},$feature);
	}
	my $ContigObj;
	if (defined($data->{DNAsequence}->[0])) {
    	my $gccount = 0;
    	my $size = 0;
    	for (my $i=0; $i < @{$data->{DNAsequence}}; $i++) {
    		my $closest;
    		foreach my $key (keys(%{$contighash})) {
    			my $dist = abs(length($data->{DNAsequence}->[$i]) - $contighash->{$key});
    			my $closestdist = abs(length($data->{DNAsequence}->[$i]) - $contighash->{$closest});
    			if (!defined($closest) || $dist < $closestdist) {
    				$closest = $key;
    			}
    		}
    		push(@{$contigset->{contigs}},{
    			id => $closest,
				"length" => length($data->{DNAsequence}->[$i]),
				md5 => Digest::MD5::md5_hex($data->{DNAsequence}->[$i]),
				sequence => $data->{DNAsequence}->[$i],
				name => $closest
    		});
    		push(@{$genomeObj->{contig_lengths}},length($data->{DNAsequence}->[$i]));
    		$size += length($data->{DNAsequence}->[$i]);
    		push(@{$genomeObj->{contig_ids}},$closest);
			for ( my $j = 0 ; $j < length($data->{DNAsequence}->[$i]) ; $j++ ) {
				if ( substr( $data->{DNAsequence}->[$i], $j, 1 ) =~ m/[gcGC]/ ) {
					$gccount++;
				}
			}
    	}
    	if ($size > 0) {
			$genomeObj->{gc_content} = $$gccount/$size;
		}
		my $sortedcontigs = [sort { $a->{sequence} cmp $b->{sequence} } @{$contigset->{contigs}}];
		my $str = "";
		for (my $i=0; $i < @{$sortedcontigs}; $i++) {
			if (length($str) > 0) {
				$str .= ";";
			}
			$str .= $sortedcontigs->[$i]->{sequence};	
		}
		$genomeObj->{md5} = Digest::MD5::md5_hex($str);
		$contigset->{md5} = $genomeObj->{md5};
		$contigset->{id} = $id.".contigs";
    	$ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($contigset);
	}
	$genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	$genomeObj->contigs($ContigObj);
	return $genomeObj;
}
=head3 build_fba_object

Definition:
	Genome = $self->build_fba_object({} params);
Description:
	Returns typed object for FBA
		
=cut
sub build_fba_object {
	my($self,$model,$params) = @_;
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
		Bio::KBase::ObjectAPI::logging::log("Getting reaction likelihoods from ".$model->rxnprobs_ref());
		my $rxnprobs = $self->get_object($model->rxnprobs_ref(),undef,{refreshcache => 1});
	    if (!defined($rxnprobs)) {
	    	$self->error("Reaction likelihood retrieval from ".$model->rxnprobs_ref()." failed");
	    }		
		$fba->{parameters}->{"Objective coefficient file"} = "ProbModelReactionCoefficients.txt";
		$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"} = [];
		my $rxncosts = {};
		foreach my $rxn (@{$rxnprobs->{reaction_probabilities}}) {
			$rxncosts->{$rxn->[0]} = (1-$rxn->[1]); # ID is first element, likelihood is second element
		}
		my $compindecies = {};
		my $comps = $model->modelcompartments();
		for (my $i=0; $i < @{$comps}; $i++) {
			$compindecies->{$comps->[$i]->compartmentIndex()}->{$comps->[$i]->compartment()->id()} = 1;
		}
		foreach my $compindex (keys(%{$compindecies})) {
			my $tmp = $model->template();
			my $tmprxns = $tmp->reactions();
			for (my $i=0; $i < @{$tmprxns}; $i++) {
				my $tmprxn = $tmprxns->[$i];
				my $tmpid = $tmprxn->id().$compindex;
				if (defined($rxncosts->{$tmprxn->id()})) {
					push(@{$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"}},"forward\t".$tmpid."\t".$rxncosts->{$tmprxn->id()});
					push(@{$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"}},"reverse\t".$tmpid."\t".$rxncosts->{$tmprxn->id()});
				}
			}
		}	
    	Bio::KBase::ObjectAPI::logging::log("Added reaction coefficients from reaction likelihoods in ".$model->rxnprobs_ref());
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
    	$input->{destination} = "/".Bio::KBase::ObjectAPI::config::username()."/modelseed/genomes/";
    	if ($input->{plantseed} == 1) {
    		$input->{destination} = "/".Bio::KBase::ObjectAPI::config::username()."/plantseed/genomes/";
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
    	$input->{destination} = "/".Bio::KBase::ObjectAPI::config::username()."/home/models/";
    	if ($input->{plantseed} == 1) {
    		$input->{destination} = "/".Bio::KBase::ObjectAPI::config::username()."/plantseed/models/";
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
    return $self->get_model_summary($model);
}

sub check_jobs {
	my($self,$input) = @_;
	$input = $self->validate_args($input,[],{
		jobs => []
	});
	my $output = {};
	if (@{$input->{jobs}} == 0) {
		my $enumoutput = $self->app_service()->enumerate_tasks(0,10000);
		for (my $i=0; $i < @{$enumoutput}; $i++) {
			if ($enumoutput->[$i]->{app} eq "RunProbModelSEEDJob") {
				$output->{$enumoutput->[$i]->{id}} = $enumoutput->[$i];
			}
		}
	} else {
		$output = $self->app_service()->query_tasks($input->{jobs});
	}
	return $output;
}
#****************************************************************************
#Apps
#****************************************************************************
sub app_harness {
	my($self,$command,$parameters) = @_;
	my $starttime = time();
	if (Bio::KBase::ObjectAPI::config::run_as_app() == 1) {
		Bio::KBase::ObjectAPI::logging::log($command.": issuing app");
		my $task = $self->app_service()->start_app("RunProbModelSEEDJob",{command => $command,arguments => $parameters},"/".Bio::KBase::ObjectAPI::config::username()."/".Bio::KBase::ObjectAPI::config::home_dir()."/");
		Bio::KBase::ObjectAPI::logging::log($command.": app issued");
		return $task->{id};
	} else {
		Bio::KBase::ObjectAPI::logging::log($command.": job started");
	    my $output = $self->$command($parameters);
	    Bio::KBase::ObjectAPI::logging::log($command.": job done (elapsed time ".(time()-$starttime).")");
	    return $output;
	}
}

sub ComputeReactionProbabilities {
	my($self,$parameters) = @_;
    $parameters = $self->validate_args($parameters,["genome", "template", "rxnprobs"], {});
    my $cmd = Bio::KBase::ObjectAPI::config::bin_directory()."/bin/ms-probanno ".$parameters->{genome}." ".$parameters->{template}." ".$parameters->{rxnprobs}." --token '".Bio::KBase::ObjectAPI::config::token()."'";
    system($cmd);
    if ($? != 0) {
    	$self->error("Calculating reaction likelihoods failed!");
    }
    Bio::KBase::ObjectAPI::logging::log("Finished calculating reaction likelihoods");
    # Get the object, add the job result, and save it back to workspace.
    my $rxnprob = $self->get_object($parameters->{rxnprobs},"rxnprobs");
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
		start_time => 0,
		end_time => time(),
		elapsed_time => time()-0,
		output_files => [[$parameters->{rxnprobs}]],
		job_output => "",
		hostname => "https://p3.theseed.org/services/ProbModelSEED"
	};
	$self->save_object($parameters->{rxnprobs},$rxnprob,"rxnprobs");
	return $parameters->{rxnprobs};
}

sub ModelReconstruction {
	my($self,$parameters) = @_;
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
	my $genome = $self->get_genome($parameters->{genome});
    if (!defined($parameters->{output_file})) {
    	$parameters->{output_file} = $genome->id()."_model";	
    }
    if (!defined($parameters->{media})) {
		if ($genome->domain() eq "Plant" || $genome->taxonomy() =~ /viridiplantae/i) {
			$parameters->{media} = "/chenry/public/modelsupport/media/PlantHeterotrophicMedia";
		} else {
			$parameters->{media} = Bio::KBase::ObjectAPI::config::default_media();
		}
	}
    
    my $template;
    if (!defined($parameters->{templatemodel})) {
    	if ($genome->domain() eq "Plant" || $genome->taxonomy() =~ /viridiplantae/i) {
    		if (!defined($parameters->{output_path})) {
    			$parameters->{output_path} = "/".Bio::KBase::ObjectAPI::config::username()."/plantseed/models/";
    		}
    		$template = $self->get_object(Bio::KBase::ObjectAPI::config::template_dir()."plant.modeltemplate","modeltemplate");
    	} else {
    		if (!defined($parameters->{output_path})) {
    			$parameters->{output_path} = "/".Bio::KBase::ObjectAPI::config::username()."/home/models/";
    		}
    		my $classifier_data = $self->get_object(Bio::KBase::ObjectAPI::config::classifier(),"string");
    		my $class = $self->classify_genome($classifier_data,$genome);
    		if ($class eq "Gram positive") {
	    		$template = $self->get_object(Bio::KBase::ObjectAPI::config::template_dir()."GramPositive.modeltemplate","modeltemplate");
	    	} elsif ($class eq "Gram negative") {
	    		$template = $self->get_object(Bio::KBase::ObjectAPI::config::template_dir()."GramNegative.modeltemplate","modeltemplate");
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
    if ($parameters->{genome} =~ m/^REFSEQ:(.+)$/ || $parameters->{genome} =~ m/^PATRIC:(.+)$/ || $parameters->{genome} =~ m/^RAST:(.+)$/ || $parameters->{genome} =~ m/^PUBSEED:(.+)$/ || $parameters->{genome} =~ m/^KBASE:(.+)$/) {
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
    	my $templateref = $template->_reference();
    	$templateref =~ s/\|\|$//; # Remove the extraneous || at the end of the reference
    	my $rxnprobsref = $folder."/".$genome->id().".rxnprobs";
    	$self->ComputeReactionProbabilities({
    		genome => $genomeref,
    		template => $templateref,
    		rxnprobs => $rxnprobsref
    	});
    	$mdl->rxnprobs_ref($rxnprobsref);
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
		start_time => 0,
		end_time => time(),
		elapsed_time => time()-0,
		output_files => [[$parameters->{output_path}."/".$parameters->{output_file}]],
		job_output => "",
		hostname => "https://p3.theseed.org/services/ProbModelSEED"
    });
    $self->save_object($folder."/fba",undef,"folder");
    $self->save_object($folder."/gapfilling",undef,"folder");
    my $output = $self->save_object($parameters->{output_path}.$parameters->{output_file},$mdl,"model");
    my $summary;
    if ($parameters->{gapfill} == 1) {
    	$summary = $self->GapfillModel({
    		model => $parameters->{output_path}."/".$parameters->{output_file},
    		media => $parameters->{media},
    		integrate_solution => 1,
    		probanno => $parameters->{probanno},
    	});    	
    	if ($parameters->{predict_essentiality} == 1) {
    		$self->FluxBalanceAnalysis({
	    		model => $parameters->{output_path}."/".$parameters->{output_file},
	    		media => $parameters->{media},
	    		predict_essentiality => 1
	    	});
    	}	
    } else {
    	$summary = $self->save_model($mdl,$parameters->{output_path}."/".$parameters->{output_file},{},1);
    }
    return $parameters->{output_path}.$parameters->{output_file};
}

sub FluxBalanceAnalysis {
	my($self,$parameters) = @_;
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
	
    my $model = $self->get_model($parameters->{model});
    $parameters->{model} = $model->_reference();
    if (!defined($parameters->{media})) {
		if ($model->genome()->domain() eq "Plant" || $model->genome()->taxonomy() =~ /viridiplantae/i) {
			$parameters->{media} = "/chenry/public/modelsupport/media/PlantHeterotrophicMedia";
		} else {
			$parameters->{media} = Bio::KBase::ObjectAPI::config::default_media();
		}
	}
    
    #Setting output path based on model and then creating results folder
    $parameters->{output_path} = $model->wsmeta()->[2].".".$model->wsmeta()->[0]."/fba";
    if (!defined($parameters->{output_file})) {
	    my $list = $self->workspace_service()->ls({
			adminmode => Bio::KBase::ObjectAPI::config::adminmode(),
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
    Bio::KBase::ObjectAPI::logging::log("Started solving flux balance problem");
    my $objective = $fba->runFBA();
    print "Objective:".$objective."\n";
    if (!defined($objective)) {
    	$self->error("FBA failed with no solution returned! See ".$fba->jobnode());
    }
    Bio::KBase::ObjectAPI::logging::log("Got solution for flux balance problem");
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
		start_time => 0,
		end_time => time(),
		elapsed_time => time()-0,
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
	    $self->save_object("/".Bio::KBase::ObjectAPI::config::username()."/home/Feature Groups/".$model->wsmeta()->[0]."-".$fba->media()->wsmeta()->[0]."-essentials",$ftrgroup,"feature_group",{
	    	description => "Group of essential genes predicted by metabolic models",
	    	media => $parameters->{media},
	    	model => $parameters->{model}
	    });
    }
    $self->save_object($parameters->{output_path}."/".$parameters->{output_file},$fba,"fba",{
    	objective => $objective,
    	media => $parameters->{media}
    });
    return $parameters->{output_path}.$parameters->{output_file};
}

sub GapfillModel {
	my($self,$parameters) = @_;
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
		findminmedia => 0
	});
    my $model = $self->get_model($parameters->{model});
    $parameters->{model} = $model->_reference();
    if (!defined($parameters->{media})) {
		if ($model->genome()->domain() eq "Plant" || $model->genome()->taxonomy() =~ /viridiplantae/i) {
			$parameters->{media} = "/chenry/public/modelsupport/media/PlantHeterotrophicMedia";
		} else {
			$parameters->{media} = Bio::KBase::ObjectAPI::config::default_media();
		}
	}
    
    #Setting output path based on model and then creating results folder
    $parameters->{output_path} = $model->wsmeta()->[2].".".$model->wsmeta()->[0]."/gapfilling";
    if (!defined($parameters->{output_file})) {
	    my $gflist = $self->workspace_service()->ls({
			adminmode => Bio::KBase::ObjectAPI::config::adminmode(),
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
    Bio::KBase::ObjectAPI::logging::log("Started solving gap fill problem");
    my $objective = $fba->runFBA();
    $fba->parseGapfillingOutput();
    if (!defined($fba->gapfillingSolutions()->[0])) {
		$self->error("Analysis completed, but no valid solutions found!");
	}
	if (@{$fba->gapfillingSolutions()->[0]->gapfillingSolutionReactions()} == 0) {
		$self->error("No gapfilling needed on specified condition!");
	}
    Bio::KBase::ObjectAPI::logging::log("Got solution for gap fill problem");
	
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
	my $solutiondata = Bio::KBase::ObjectAPI::utilities::TOJSON($gfsols);
	
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
		start_time => 0,
		end_time => time(),
		elapsed_time => time()-0,
		output_files => [[ $parameters->{output_path}."/".$parameters->{output_file}]],
		job_output => "",
		hostname => "https://p3.theseed.org/services/ProbModelSEED",
    });
	$self->save_object($parameters->{output_path}."/".$parameters->{output_file},$fba,"fba",{
		integrated_solution => 0,
		solutiondata => $solutiondata,
		integratedindex => 0,
		media => $parameters->{media},
		integrated => $parameters->{integrate_solution}
	});
	$self->save_object($parameters->{output_path}."/".$parameters->{output_file}.".gftbl",$gftbl,"string",{
	   description => "Tab delimited table of reactions gapfilled in metabolic model",
	   fba => $parameters->{output_file},
	   media => $parameters->{media},
	   model => $parameters->{model}
	});
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
	$model->add("gapfillings",{
		id => $fba->id(),
		gapfill_id => $fba->id(),
		fba_ref => $fba->_reference(),
		integrated => $parameters->{integrate_solution},
		integrated_solution => 0,
		media_ref => $parameters->{media},
	});
	my $write_files = 0;
	if ($parameters->{integrate_solution}) {
		my $report = $model->integrateGapfillSolutionFromObject({
			gapfill => $fba
		});
		$write_files = 1;
	}
	$self->save_model($model,$model->wsmeta()->[2].$model->wsmeta()->[0],{},$write_files);
	return $model->wsmeta()->[2].$model->wsmeta()->[0];
}

sub MergeModels {
	my($self,$parameters) = @_;
	$parameters = $self->validate_args($parameters,["models"],{
    	output_path => "/".Bio::KBase::ObjectAPI::config::username()."/home/models/",
    	output_file => "CommunityModel",
    });
    #Pulling first model to obtain biochemistry ID
	my $model = $self->get_model($parameters->{models}->[0]->[0]);
	my $genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new({
		id => $parameters->{output_file}."Genome",
		scientific_name => $parameters->{output_file}."Genome",
		domain => "Community",
		genetic_code => 11,
		dna_size => 0,
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "PATRIC",
		source_id => $parameters->{output_file}."Genome",
		md5 => "",
		taxonomy => "Community",
		gc_content => 0,
		complete => 0,
		publications => [],
		features => [],
    });
    $genomeObj->parent($self->PATRICStore());
	#Creating new community model
	my $commdl = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->new({
		source_id => $parameters->{output_file},
		source => "PATRIC",
		id => $parameters->{output_file},
		type => "CommunityModel",
		name => $parameters->{output_file},
		template_ref => $model->template_ref(),
		template_refs => [$model->template_ref()],
		modelreactions => [],
		modelcompounds => [],
		modelcompartments => [],
		biomasses => [],
		gapgens => [],
		gapfillings => [],
	});
	$commdl->parent($self->PATRICStore());
	my $cmpsHash = {
		e => $commdl->addCompartmentToModel({
			compartment => $model->template()->biochemistry()->getObject("compartments","e"),
			pH => 7,
			potential => 0,
			compartmentIndex => 0
		}),
		c => $commdl->addCompartmentToModel({
			compartment => $model->template()->biochemistry()->getObject("compartments","c"),
			pH => 7,
			potential => 0,
			compartmentIndex => 0
		})
	};
	my $totalAbundance = 0;
	for (my $i=0; $i < @{$parameters->{models}}; $i++) {
		$totalAbundance += $parameters->{models}->[$i]->[1];
	}
	my $biocount = 1;
	my $primbio = $commdl->add("biomasses",{
		id => "bio1",
		name => "bio1",
		other => 1,
		dna => 0,
		rna => 0,
		protein => 0,
		cellwall => 0,
		lipid => 0,
		cofactor => 0,
		energy => 0
	});
	my $biomassCompound = $model->template()->biochemistry()->getObject("compounds","cpd11416");
	my $biocpd = $commdl->add("modelcompounds",{
		id => $biomassCompound->id()."_".$cmpsHash->{c}->id(),
		compound_ref => $biomassCompound->_reference(),
		charge => 0,
		modelcompartment_ref => "~/modelcompartments/id/".$cmpsHash->{c}->id()
	});
	$primbio->add("biomasscompounds",{
		modelcompound_ref => "~/modelcompounds/id/".$biocpd->id(),
		coefficient => 1
	});
	for (my $i=0; $i < @{$parameters->{models}}; $i++) {
		print "Loading model ".$parameters->{models}->[$i]->[0]."\n";
		if ($i > 0) {
			$model = $self->get_model($parameters->{models}->[$i]->[0]);
		}
		my $biomassCpd = $model->getObject("modelcompounds","cpd11416_c0");
		#Adding genome, features, and roles to master mapping and annotation
		my $mdlgenome = $model->genome();
		$genomeObj->dna_size($genomeObj->dna_size()+$mdlgenome->dna_size());
		$genomeObj->num_contigs($genomeObj->num_contigs()+$mdlgenome->num_contigs());
		$genomeObj->gc_content($genomeObj->gc_content()+$mdlgenome->dna_size()*$mdlgenome->gc_content());
		push(@{$genomeObj->{contig_lengths}},@{$mdlgenome->{contig_lengths}});
		push(@{$genomeObj->{contig_ids}},@{$mdlgenome->{contig_ids}});	
		print "Loading features\n";
		for (my $j=0; $j < @{$mdlgenome->features()}; $j++) {
			if (!defined($mdlgenome->features()->[$j]->quality())) {
				$mdlgenome->features()->[$j]->quality({});
			}
			$genomeObj->add("features",$mdlgenome->features()->[$j]);
		}
		$commdl->template_refs()->[$i+1] = $model->template_ref();
		#Adding compartments to community model
		my $cmps = $model->modelcompartments();
		print "Loading compartments\n";
		for (my $j=0; $j < @{$cmps}; $j++) {
			if ($cmps->[$j]->compartment()->id() ne "e") {
				$cmpsHash->{$cmps->[$j]->compartment()->id()} = $commdl->addCompartmentToModel({
					compartment => $cmps->[$j]->compartment(),
					pH => 7,
					potential => 0,
					compartmentIndex => ($i+1)
				});
			}
		}
		#Adding compounds to community model
		my $translation = {};
		Bio::KBase::ObjectAPI::logging::log("Loading compounds");
		my $cpds = $model->modelcompounds();
		for (my $j=0; $j < @{$cpds}; $j++) {
			my $cpd = $cpds->[$j];
			my $rootid = $cpd->compound()->id();
			if ($cpd->id() =~ m/(.+)_([a-zA-Z]\d+)/) {
				$rootid = $1;
			}
			my $comcpd = $commdl->getObject("modelcompounds",$rootid."_".$cmpsHash->{$cpd->modelcompartment()->compartment()->id()}->id());
			if (!defined($comcpd)) {
				$comcpd = $commdl->add("modelcompounds",{
					id => $rootid."_".$cmpsHash->{$cpd->modelcompartment()->compartment()->id()}->id(),
					compound_ref => $cpd->compound_ref(),
					charge => $cpd->charge(),
					formula => $cpd->formula(),
					modelcompartment_ref => "~/modelcompartments/id/".$cmpsHash->{$cpd->modelcompartment()->compartment()->id()}->id(),
				});
			}
			$translation->{$cpd->id()} = $comcpd->id();
		}
		Bio::KBase::ObjectAPI::logging::log("Loading reactions");
		#Adding reactions to community model
		my $rxns = $model->modelreactions();
		for (my $j=0; $j < @{$rxns}; $j++) {
			my $rxn = $rxns->[$j];
			my $rootid = $rxn->reaction()->id();
			if ($rxn->id() =~ m/(.+)_([a-zA-Z]\d+)/) {
				$rootid = $1;
			}
			my $originalcmpid = $rxn->modelcompartment()->compartment()->id();
			if ($originalcmpid eq "e0") {
				$originalcmpid = "c0";
			}
			if (!defined($commdl->getObject("modelreactions",$rootid."_".$cmpsHash->{$originalcmpid}->id()))) {
				my $comrxn = $commdl->add("modelreactions",{
					id => $rootid."_".$cmpsHash->{$originalcmpid}->id(),
					reaction_ref => $rxn->reaction_ref(),
					direction => $rxn->direction(),
					protons => $rxn->protons(),
					modelcompartment_ref => "~/modelcompartments/id/".$cmpsHash->{$originalcmpid}->id(),
					probability => $rxn->probability()
				});
				for (my $k=0; $k < @{$rxn->modelReactionProteins()}; $k++) {
					$comrxn->add("modelReactionProteins",$rxn->modelReactionProteins()->[$k]);
				}
				for (my $k=0; $k < @{$rxn->modelReactionReagents()}; $k++) {
					$comrxn->add("modelReactionReagents",{
						modelcompound_ref => "~/modelcompounds/id/".$translation->{$rxn->modelReactionReagents()->[$k]->modelcompound()->id()},
						coefficient => $rxn->modelReactionReagents()->[$k]->coefficient()
					});
				}
			}
		}
		Bio::KBase::ObjectAPI::logging::log("Loading biomass");
		#Adding biomass to community model
		my $bios = $model->biomasses();
		for (my $j=0; $j < @{$bios}; $j++) {
			my $bio = $bios->[$j]->cloneObject();
			$bio->parent($commdl);
			for (my $k=0; $k < @{$bio->biomasscompounds()}; $k++) {
				$bio->biomasscompounds()->[$k]->modelcompound_ref("~/modelcompounds/id/".$translation->{$bios->[$j]->biomasscompounds()->[$k]->modelcompound()->id()});
			}
			$bio = $commdl->add("biomasses",$bio);
			$biocount++;
			$bio->id("bio".$biocount);
			$bio->name("bio".$biocount);
		}
		Bio::KBase::ObjectAPI::logging::log("Loading primary biomass");
		#Adding biomass component to primary composite biomass reaction
		$primbio->add("biomasscompounds",{
			modelcompound_ref => "~/modelcompounds/id/".$translation->{$biomassCpd->id()},
			coefficient => -1*$parameters->{models}->[$i]->[1]/$totalAbundance
		});
	}
	Bio::KBase::ObjectAPI::logging::log("Merge complete!");	
	$self->save_object($parameters->{output_path}."/.".$parameters->{output_file}."/".$genomeObj->id(),$genomeObj,"genome",{});
	$commdl->genome_ref($genomeObj->_reference());
	$self->save_model($commdl,$parameters->{output_path}."/".$parameters->{output_file},{},1);
	return $parameters->{output_path}."/".$parameters->{output_file};
}

sub load_to_shock {
	my($self,$data) = @_;
	my $uuid = Data::UUID->new()->create_str();
	File::Path::mkpath Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY();
	my $filename = Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY().$uuid;
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($filename,[$data]);
	my $output = Bio::KBase::ObjectAPI::utilities::runexecutable("curl -H \"Authorization: OAuth ".Bio::KBase::ObjectAPI::config::token()."\" -X POST -F 'upload=\@".$filename."' ".Bio::KBase::ObjectAPI::config::shock_url()."/node");
	$output = Bio::KBase::ObjectAPI::utilities::FROMJSON(join("\n",@{$output}));
	return Bio::KBase::ObjectAPI::config::shock_url()."/node/".$output->{data}->{id};
}

#****************************************************************************
#Constructor
#****************************************************************************
sub new {
    my($class, $parameters) = @_;
    my $self = {};
    bless $self, $class;
    $parameters = $self->validate_args($parameters,["token","username","fbajobcache","fbajobdir","mfatoolkitbin"],{
    	source => "PATRIC",
    	data_api_url => "https://www.patricbrc.org/api/",
    	"mssserver-url" => "http://bio-data-1.mcs.anl.gov/services/ms_fba",
    	"workspace-url" => "http://p3.theseed.org/services/Workspace",
    	appservice_url => "http://p3.theseed.org/services/app_service",
    	"shock-url" => "http://p3.theseed.org/services/shock_api",
    	adminmode => 0,
    	method => "unknown",
    	run_as_app => 1,
    	home_dir => "modelseed",
    	file_cache => "/disks/p3/fba/filecache/",
    	cache_targets => ["/chenry/public/modelsupport/biochemistry/default.biochem"],
    	biochemistry => "/chenry/public/modelsupport/biochemistry/default.biochem",
    	default_media => "/chenry/public/modelsupport/patric-media/Complete",
    	classifier => "/chenry/public/modelsupport/classifiers/gramclassifier.string",
    	template_dir => "/chenry/public/modelsupport/templates/"
    });
    Bio::KBase::ObjectAPI::config::appservice_url($parameters->{appservice_url});
    Bio::KBase::ObjectAPI::config::home_dir($parameters->{home_dir});
    Bio::KBase::ObjectAPI::config::run_as_app($parameters->{run_as_app});
    Bio::KBase::ObjectAPI::config::method($parameters->{method});
    Bio::KBase::ObjectAPI::config::adminmode($parameters->{adminmode});
    Bio::KBase::ObjectAPI::config::shock_url($parameters->{"shock-url"});
    Bio::KBase::ObjectAPI::config::workspace_url($parameters->{"workspace-url"});
    Bio::KBase::ObjectAPI::config::mssserver_url($parameters->{"mssserver-url"});
    Bio::KBase::ObjectAPI::config::template_dir($parameters->{template_dir});
    Bio::KBase::ObjectAPI::config::classifier($parameters->{classifier});
    Bio::KBase::ObjectAPI::config::cache_targets($parameters->{cache_targets});
    Bio::KBase::ObjectAPI::config::file_cache($parameters->{file_cache});
    Bio::KBase::ObjectAPI::config::token($parameters->{token});
    Bio::KBase::ObjectAPI::config::username($parameters->{username});
    Bio::KBase::ObjectAPI::config::data_api_url($parameters->{data_api_url});
	Bio::KBase::ObjectAPI::config::FinalJobCache($parameters->{fbajobcache});
    Bio::KBase::ObjectAPI::config::default_media($parameters->{default_media});
    Bio::KBase::ObjectAPI::config::default_biochemistry($parameters->{biochemistry});
	Bio::KBase::ObjectAPI::config::source($parameters->{source});
    Bio::KBase::ObjectAPI::config::config_directory($parameters->{fbajobdir});
    Bio::KBase::ObjectAPI::config::mfatoolkit_binary($parameters->{mfatoolkitbin});
    Bio::KBase::ObjectAPI::config::mfatoolkit_job_dir($parameters->{fbajobdir});
    Bio::KBase::ObjectAPI::config::bin_directory($parameters->{bin_directory});
    Bio::KBase::ObjectAPI::logging::log("ProbModelSEEDHelper initialized");
    return $self;
}

1;
