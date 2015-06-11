########################################################################
# Bio::KBase::ObjectAPI::KBaseStore - A class for managing KBase object retrieval from KBase
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location:
#   Mathematics and Computer Science Division, Argonne National Lab;
#   Computation Institute, University of Chicago
#
# Date of module creation: 2014-01-4
########################################################################

=head1 Bio::KBase::ObjectAPI::PATRICStore 

Class for managing object retreival from PATRIC workspace

=head2 ABSTRACT

=head2 NOTE


=head2 METHODS

=head3 new

    my $Store = Bio::KBase::ObjectAPI::PATRICStore->new({});

This initializes a Storage interface object. This accepts a hash
or hash reference to configuration details:

=over

=item auth

Authentication token to use when retrieving objects

=item workspace

Client or server class for accessing a PATRIC workspace

=back

=head3 Object Methods

=cut

package Bio::KBase::ObjectAPI::PATRICStore;
use Moose;
use Bio::KBase::ObjectAPI::utilities;
use Data::Dumper;

use Class::Autouse qw(
    Bio::KBase::ObjectAPI::KBaseRegulation::Regulome
    Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry
    Bio::KBase::ObjectAPI::KBaseGenomes::Genome
    Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet
    Bio::KBase::ObjectAPI::KBaseBiochem::Media
    Bio::KBase::ObjectAPI::KBaseFBA::ModelTemplate
    Bio::KBase::ObjectAPI::KBaseOntology::Mapping
    Bio::KBase::ObjectAPI::KBaseFBA::FBAModel
    Bio::KBase::ObjectAPI::KBaseBiochem::BiochemistryStructures
    Bio::KBase::ObjectAPI::KBaseFBA::Gapfilling
    Bio::KBase::ObjectAPI::KBaseFBA::FBA
    Bio::KBase::ObjectAPI::KBaseFBA::Gapgeneration
    Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSet
    Bio::KBase::ObjectAPI::KBasePhenotypes::PhenotypeSimulationSet
);
use Module::Load;

my $typetrans = {
	model => "Bio::KBase::ObjectAPI::KBaseFBA::FBAModel",
	modeltemplate => "Bio::KBase::ObjectAPI::KBaseFBA::ModelTemplate",
	fba => "Bio::KBase::ObjectAPI::KBaseFBA::FBA",
	biochemistry => "Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry",
	media => "Bio::KBase::ObjectAPI::KBaseBiochem::Media",
	mapping => "Bio::KBase::ObjectAPI::KBaseOntology::Mapping",
	genome => "Bio::KBase::ObjectAPI::KBaseGenomes::Genome",
};
my $transform = {
	media => {
		in => "transform_media_from_ws",
		out => "transform_media_to_ws"
	},
	genome => {
		in => "transform_genome_from_ws",
		out => "transform_genome_to_ws"
	},
	model => {
		in => "transform_model_from_ws"
	}
};
my $jsontypes = {
	job_result => 1
};

#***********************************************************************************************************
# ATTRIBUTES:
#***********************************************************************************************************
has workspace => ( is => 'rw', isa => 'Ref', required => 1);
has data_api_url => ( is => 'rw', isa => 'Str', required => 1);
has cache => ( is => 'rw', isa => 'HashRef',default => sub { return {}; });
has adminmode => ( is => 'rw', isa => 'Num',default => 0);
has setowner => ( is => 'rw', isa => 'Str');
has provenance => ( is => 'rw', isa => 'ArrayRef',default => sub { return []; });
has user_override => ( is => 'rw', isa => 'Str',default => "");

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
sub object_meta {
	my ($self,$ref) = @_;
	return $self->cache()->{$ref}->[0];
}

sub get_objects {
	my ($self,$refs,$options) = @_;
	#Checking cache for objects
	my $newrefs = [];
	my $solrrefs = [];
	for (my $i=0; $i < @{$refs}; $i++) {
		if (!defined($self->cache()->{$refs->[$i]}) || defined($options->{refreshcache})) {
    		if ($refs->[$i] =~ m/^PATRICSOLR:(.+)/) {
    			$self->cache()->{$refs->[$i]} = $self->genome_from_solr($1);
    			$self->cache()->{$refs->[$i]}->[1]->parent($self);
    			$self->cache()->{$refs->[$i]}->[1]->wsmeta($self->cache()->{$refs->[$i]}->[0]);
    			$self->cache()->{$refs->[$i]}->[1]->_reference($refs->[$i]."||");
    		} else {
    			push(@{$newrefs},$refs->[$i]);
    		}
    	}
	}
	#Pulling objects from workspace
	if (@{$newrefs} > 0) {
		my $objdatas = $self->workspace()->get({adminmode => $self->adminmode(),objects => $newrefs});
		my $object;
		for (my $i=0; $i < @{$objdatas}; $i++) {
			$self->cache()->{$objdatas->[$i]->[0]->[4]} = $objdatas->[$i];
			if (defined($objdatas->[$i]->[0]->[11]) && length($objdatas->[$i]->[0]->[11]) > 0) {
				my $ua = LWP::UserAgent->new();
				my $res = $ua->get($objdatas->[$i]->[0]->[11]."?download",Authorization => "OAuth " . $self->workspace()->{token});
				$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1] = $res->{_content};
			}
			if (defined($typetrans->{$objdatas->[$i]->[0]->[1]})) {
				my $class = $typetrans->{$objdatas->[$i]->[0]->[1]};
				if (defined($transform->{$objdatas->[$i]->[0]->[1]}->{in})) {
	    			my $function = $transform->{$objdatas->[$i]->[0]->[1]}->{in};
	    			$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1] = $self->$function($self->cache()->{$objdatas->[$i]->[0]->[4]}->[1],$self->cache()->{$objdatas->[$i]->[0]->[4]}->[0]);
	    			if (ref($self->cache()->{$objdatas->[$i]->[0]->[4]}->[1]) eq "HASH") {
	    				$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1] = $class->new($self->cache()->{$objdatas->[$i]->[0]->[4]}->[1]);
	    			}
				} else {
					$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1] = $class->new(Bio::KBase::ObjectAPI::utilities::FROMJSON($self->cache()->{$objdatas->[$i]->[0]->[4]}->[1]));
				}
				$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1]->wsmeta($self->cache()->{$objdatas->[$i]->[0]->[4]}->[0]);
				$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1]->parent($self);
				$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1]->_reference($objdatas->[$i]->[0]->[2].$objdatas->[$i]->[0]->[0]."||");
			} elsif (defined($jsontypes->{$objdatas->[$i]->[0]->[1]})) {
				$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1] = Bio::KBase::ObjectAPI::utilities::FROMJSON($self->cache()->{$objdatas->[$i]->[0]->[4]}->[1]);
			}
			$self->cache()->{$objdatas->[$i]->[0]->[2].$objdatas->[$i]->[0]->[0]} = $self->cache()->{$objdatas->[$i]->[0]->[4]};
		}
	}
	my $objs = [];
	for (my $i=0; $i < @{$refs}; $i++) {
		$objs->[$i] = $self->cache()->{$refs->[$i]}->[1];
	}
	return $objs;
}

sub get_object {
    my ($self,$ref,$options) = @_;
    return $self->get_objects([$ref])->[0];
}

sub save_object {
    my ($self,$object,$ref,$meta,$type,$overwrite) = @_;
    my $output = $self->save_objects({$ref => {usermeta => $meta,object => $object,type => $type}},$overwrite);
    return $output->{$ref};
}

sub save_objects {
    my ($self,$refobjhash,$overwrite) = @_;
    if (!defined($overwrite)) {
    	$overwrite = 1;
    }
    my $input = {
    	objects => [],
    	overwrite => 1,
    	adminmode => $self->adminmode(),
    };
    if (defined($self->adminmode()) && $self->adminmode() == 1 && defined($self->setowner())) {
    	$input->{setowner} = $self->setowner();
    }
    my $reflist;
    my $objecthash = {};
    foreach my $ref (keys(%{$refobjhash})) {
    	my $obj = $refobjhash->{$ref};
    	push(@{$reflist},$ref);
    	$objecthash->{$ref} = 0;
    	if (defined($typetrans->{$obj->{type}})) {
    		$objecthash->{$ref} = 1;
    		$obj->{object}->parent($self);
    		if (defined($transform->{$obj->{type}}->{out})) {
    			my $function = $transform->{$obj->{type}}->{out};
    			push(@{$input->{objects}},[$ref,$obj->{type},$obj->{usermeta},$self->$function($obj->{object},$obj->{usermeta})]);
    		} else {
    			push(@{$input->{objects}},[$ref,$obj->{type},$obj->{usermeta},$obj->{object}->toJSON()]);
    		}
    	} elsif (defined($jsontypes->{$obj->{type}})) {
    		push(@{$input->{objects}},[$ref,$obj->{type},$obj->{usermeta},Bio::KBase::ObjectAPI::utilities::TOJSON($obj->{object})]);
    	} else {
    		push(@{$input->{objects}},[$ref,$obj->{type},$obj->{usermeta},$obj->{object}]);
    	}
    }
    my $listout = $self->workspace()->create($input);
    my $output = {};
    for (my $i=0; $i < @{$listout}; $i++) {
    	$output->{$reflist->[$i]} = $listout->[$i];
    	$self->cache()->{$reflist->[$i]} = [$listout->[$i],$refobjhash->{$reflist->[$i]}->{object}];
    	$self->cache()->{$listout->[$i]->[2].$listout->[$i]->[0]} = [$listout->[$i],$refobjhash->{$reflist->[$i]}->{object}];
    	$self->cache()->{$listout->[$i]->[4]} = [$listout->[$i],$refobjhash->{$reflist->[$i]}->{object}];
    	if ($objecthash->{$reflist->[$i]} == 1) {
    		$self->cache()->{$reflist->[$i]}->[1]->wsmeta($listout->[$i]);
			$self->cache()->{$reflist->[$i]}->[1]->_reference($listout->[$i]->[2].$listout->[$i]->[0]."||");
    	}
    }
    return $output; 
}

sub genome_from_solr {
	my ($self,$genomeid) = @_;
	#Retrieving genome information
	my $data = Bio::KBase::ObjectAPI::utilities::rest_download({url => $self->data_api_url()."genome/?genome_id=".$genomeid."&http_accept=application/json"});
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
		$self->data_api_url()."genome/?genome_id=".$genomeid."&http_accept=application/json",
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
		my $ftrdata = Bio::KBase::ObjectAPI::utilities::rest_download({url => $self->data_api_url()."genome_feature/?genome_id=".$genomeid."&http_accept=application/json&limit(10000,$start)"},$params);
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
				my $list = ["alt_locus_tag","refseq_locus_tag","protein_id","figfam_id"];
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
	return [$meta,Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genome)];
}

sub transform_genome_from_ws {
	my ($self,$data,$meta) = @_;
	$data = Bio::KBase::ObjectAPI::utilities::FROMJSON($data);
	$data->{id} = $meta->[0];
	$data->{source} = "PATRIC";
	foreach my $gene (@{$data->{features}}) {
		delete $gene->{feature_creation_event};
		if (defined($gene->{protein_translation})) {
			$gene->{protein_translation_length} = length($gene->{protein_translation});
			$gene->{dna_sequence_length} = 3*$gene->{protein_translation_length};
			$gene->{md5} = Digest::MD5::md5_hex($gene->{protein_translation}),
			$gene->{publications} = [],
			$gene->{subsystems} = [],
			$gene->{protein_families} = [],
			$gene->{aliases} = [],
			$gene->{subsystem_data} = [],
			$gene->{regulon_data} = [],
			$gene->{atomic_regulons} = [],
			$gene->{coexpressed_fids} = [],
			$gene->{co_occurring_fids} = [],
		}
	}
	my $contigset;
	if (defined($data->{contigs})) {
		my $obj = {
			id => $meta->[0].".contigs",
			name => $data->{scientific_name},
			md5 => "",
			source_id => $meta->[0],
			source => "PATRIC",
			type => "organism",
			contigs => []
		};
		foreach my $contig (@{$data->{contigs}}) {
			push(@{$obj->{contigs}},{
				id => $contig->{id},
				length => length($contig->{dna}),
				sequence => $contig->{dna},
				md5 => Digest::MD5::md5_hex($contig->{dna}),
			});
		}
		$contigset = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($obj);
		delete $data->{contigs};
	}
	$data = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($data);
	if (defined($contigset)) {
		$data->contigs($contigset);
	}
	return $data;
}

sub transform_genome_to_ws {
	my ($self,$data,$meta) = @_;
	return $data;
}

sub transform_model_from_ws {
	my ($self,$data,$meta) = @_;
	$data = Bio::KBase::ObjectAPI::utilities::FROMJSON($data);
	my $obj = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->new($data);
	$obj->parent($self);
	my $gflist = $self->workspace()->ls({
		adminmode => $self->adminmode(),
		paths => [$meta->[2].".".$meta->[0]."/gapfilling"],
		excludeDirectories => 1,
		excludeObjects => 0,
		recursive => 1,
		query => {type => "fba"}
	});
	if (defined($gflist->{$meta->[2].".".$meta->[0]."/gapfilling"})) {
		$gflist = $gflist->{$meta->[2].".".$meta->[0]."/gapfilling"};
		for (my $i=0; $i < @{$gflist}; $i++) {
			if ($gflist->[$i]->[0] ne Bio::KBase::ObjectAPI::utilities::get_global("gapfill name")) {
				if ($gflist->[$i]->[7]->{integrated} == 1) {
					if (defined($gflist->[$i]->[7]->{solutiondata})) {
						my $soldata = Bio::KBase::ObjectAPI::utilities::FROMJSON($gflist->[$i]->[7]->{solutiondata});
						if (defined($soldata->[$gflist->[$i]->[7]->{integratedindex}])) {
							my $sol = $soldata->[$gflist->[$i]->[7]->{integratedindex}];
							for (my $j=0; $j < @{$sol}; $j++) {
								my $rxnobj = $obj->getLinkedObject($sol->[$j]->{reaction_ref});
								my $cmpobj = $obj->getLinkedObject($sol->[$j]->{compartment_ref});
								if (ref($rxnobj) eq "Bio::KBase::ObjectAPI::KBaseBiochem::Reaction") {
									my $mdlrxn = $obj->getObject("modelreactions",$rxnobj->id()."_".$cmpobj->id().$sol->[$j]->{compartmentIndex});
									if (defined($mdlrxn)) {
										if ($mdlrxn->direction() eq ">" && $sol->[$j]->{direction} eq "<") {
											$mdlrxn->direction("=");
										} elsif ($mdlrxn->direction() eq "<" && $sol->[$j]->{direction} eq ">") {
											$mdlrxn->direction("=");
										}
									} else {
										my $mdlcmp = $obj->addCompartmentToModel({compartment => $cmpobj,pH => 7,potential => 0,compartmentIndex => $sol->[$j]->{compartmentIndex}});
										$mdlrxn = $obj->addReactionToModel({
											reaction => $rxnobj,
											direction => $sol->[$j]->{direction},
											overrideCompartment => $mdlcmp
										});
									}
								} else {
									my $mdlrxn = $obj->getObject("modelreactions",$rxnobj->id());
									if (defined($mdlrxn)) {
										if ($mdlrxn->direction() eq ">" && $sol->[$j]->{direction} eq "<") {
											$mdlrxn->direction("=");
										} elsif ($mdlrxn->direction() eq "<" && $sol->[$j]->{direction} eq ">") {
											$mdlrxn->direction("=");
										}
									} else {
										$mdlrxn = $rxnobj->cloneObject();
										$obj->add("modelreactions",$mdlrxn);
										$mdlrxn->parent($rxnobj->parent());
										my $prots = $mdlrxn->modelReactionProteins();
										for (my $m=0; $m < @{$prots}; $m++) {
											$mdlrxn->remove("modelReactionProteins",$prots->[$m]);
										}
										my $rgts = $mdlrxn->modelReactionReagents();
										for (my $m=0; $m < @{$rgts}; $m++) {
											if (!defined($obj->getObject("modelcompounds",$rgts->[$m]->modelcompound()->id()))) {
												$obj->add("modelcompounds",$rgts->[$m]->modelcompound()->cloneObject());		
												if (!defined($obj->getObject("modelcompartments",$rgts->[$m]->modelcompound()->modelcompartment()->id()))) {
													$obj->add("modelcompartments",$rgts->[$m]->modelcompound()->modelcompartment()->cloneObject());
												}
											}
										}
										$mdlrxn->parent($obj);
									}
								}
							}
						}
					}
				}
			}
		}
	}
	return $obj;
}

sub transform_media_from_ws {
	my ($self,$data,$meta) = @_;
	my $object = {
		id => $meta->[0],
		name => $meta->[7]->{name},
		type => $meta->[7]->{type},
		isMinimal => $meta->[7]->{isMinimal},
		isDefined => $meta->[7]->{isDefined},
		source_id => $meta->[7]->{source_id},
		mediacompounds => []
	};
	my $array = [split(/\n/,$data)];
	my $heading = [split(/\t/,$array->[0])];
	my $headinghash = {};
	for (my $i=1; $i < @{$heading}; $i++) {
		$headinghash->{$heading->[$i]} = $i;
	}
	my $biochem;
	for (my $i=1; $i < @{$array}; $i++) {
		my $subarray = [split(/\t/,$array->[$i])];
		my $cpdobj = {
			concentration => 0.001,
			minFlux => -100,
			maxFlux => 100
		};
		my $name;
		if (defined($headinghash->{id})) {
			$name = $subarray->[$headinghash->{id}];
			if ($subarray->[$headinghash->{id}] =~ /cpd\d+/) {
				$cpdobj->{compound_ref} = "/chenry/public/modelsupport/biochemistry/default.biochem||/compounds/id/".$subarray->[$headinghash->{id}];
			}
		} elsif (defined($headinghash->{name})) {
			$name = $subarray->[$headinghash->{name}];
		}
		if (!defined($cpdobj->{compound_ref})) {
			if (defined($name)) {
				if (!defined($biochem)) {
					$biochem = $self->get_object("/chenry/public/modelsupport/biochemistry/default.biochem");
				}
				my $biocpdobj = $biochem->searchForCompound($name);
				if (defined($biocpdobj)) {
					$cpdobj->{compound_ref} = $biocpdobj->_reference();
				}
			}
		}
		if (defined($cpdobj->{compound_ref})) {
			if ($headinghash->{concentration}) {
				$cpdobj->{concentration} = $subarray->[$headinghash->{concentration}];
			}
			if ($headinghash->{minflux}) {
				$cpdobj->{minFlux} = $subarray->[$headinghash->{minflux}];
			}
			if ($headinghash->{maxflux}) {
				$cpdobj->{maxFlux} = $subarray->[$headinghash->{maxflux}];
			}
			push(@{$object->{mediacompounds}},$cpdobj);
		}
	}
	return $object;
}

sub transform_media_to_ws {
	my ($self,$object,$meta) = @_;
	$meta->{name} = $object->name();
	$meta->{type} = $object->type();
	$meta->{isMinimal} = $object->isMinimal();
	$meta->{isDefined} = $object->isDefined();
	$meta->{source_id} = $object->source_id();
	$meta->{number_compounds} = @{$object->mediacompounds()};
	my $data = "id\tname\tconcentration\tminflux\tmaxflux\n";
	my $mediacpds = $object->mediacompounds();
	my $compounds = "";
	for (my $i=0; $i < @{$mediacpds}; $i++) {
		$data .= $mediacpds->[$i]->id()."\t".
			$mediacpds->[$i]->name()."\t".
			$mediacpds->[$i]->concentration()."\t".
			$mediacpds->[$i]->minFlux()."\t".
			$mediacpds->[$i]->maxFlux()."\n";
		if (length($compounds) > 0) {
			$compounds .= "|";
		}
		$compounds .= $mediacpds->[$i]->id().":".$mediacpds->[$i]->name();
	}
	$meta->{compounds} = $compounds;
	return $data;
}

sub transform_model_to_ws {
	my ($self,$object,$meta) = @_;
	$meta->{name} = $object->name();
	$meta->{type} = $object->type();
	$meta->{isMinimal} = $object->isMinimal();
	$meta->{isDefined} = $object->isDefined();
	$meta->{source_id} = $object->source_id();
	$meta->{number_compounds} = @{$object->mediacompounds()};
	my $data = "id\tname\tconcentration\tminflux\tmaxflux\n";
	my $mediacpds = $object->mediacompounds();
	my $compounds = "";
	for (my $i=0; $i < @{$mediacpds}; $i++) {
		$data .= $mediacpds->[$i]->id()."\t".
			$mediacpds->[$i]->name()."\t".
			$mediacpds->[$i]->concentration()."\t".
			$mediacpds->[$i]->minFlux()."\t".
			$mediacpds->[$i]->maxFlux()."\n";
		if (length($compounds) > 0) {
			$compounds .= "|";
		}
		$compounds .= $mediacpds->[$i]->id().":".$mediacpds->[$i]->name();
	}
	$meta->{compounds} = $compounds;
	return $data;
}

no Moose;
__PACKAGE__->meta->make_immutable;
1;
