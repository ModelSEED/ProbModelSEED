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
use Log::Log4perl;

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
	}
};
my $jsontypes = {
	job_result => 1,
	feature_group => 1,
	rxnprobs => 1
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
has file_cache => ( is => 'rw', isa => 'Str',default => "");
has cache_targets => ( is => 'rw', isa => 'HashRef',default => sub { return {}; });

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
	# Assumes object has already been retrieved and stored in cache.
	return $self->cache()->{$ref}->[0];
}

sub get_object_type {
	my ($self,$ref) = @_;
	# Assumes object has already been retrieved and stored in cache.
	return $self->cache()->{$ref}->[0]->[1];
}

sub get_object {
    my ($self,$ref,$options) = @_;
    return $self->get_objects([$ref],$options)->[0];
}

sub get_objects {
	my ($self,$refs,$options) = @_;
	#Checking cache for objects
	my $newrefs = [];
	for (my $i=0; $i < @{$refs}; $i++) {
		if ($refs->[$i] =~ m/(.+)\|\|$/) {
			$refs->[$i] = $1;
		}
		$refs->[$i] =~ s/\/+/\//g;
		if (!defined($self->cache()->{$refs->[$i]}) || defined($options->{refreshcache})) {
    		#Checking file cache for object
    		my $output = $self->read_object_from_file_cache($refs->[$i]);
    		if (defined($output)) {
    			$self->process_object($output->[0],$output->[1]);
    		} else {
    			push(@{$newrefs},$refs->[$i]);
    		}
    	}
	}
	#Pulling objects from workspace
	if (@{$newrefs} > 0) {
#		print "Objects:".Data::Dumper->Dump([{adminmode => $self->adminmode(),objects => $newrefs}])."\n";
		my $objdatas = $self->workspace()->get({adminmode => $self->adminmode(),objects => $newrefs});
		my $object;
		for (my $i=0; $i < @{$objdatas}; $i++) {
			$self->process_object($objdatas->[$i]->[0],$objdatas->[$i]->[1]);
		}
	}
	my $objs = [];
	for (my $i=0; $i < @{$refs}; $i++) {
		$objs->[$i] = $self->cache()->{$refs->[$i]}->[1];
	}
	return $objs;
}

sub process_object {
	my ($self,$meta,$data) = @_;
	#Downloading object from shock if the object is in shock
	$data = $self->download_object_from_shock($meta,$data);
	#Writing target object to file cache if they are not already there
	$self->write_object_to_file_cache($meta,$data);
	#Handling all transforms of objects
	if (defined($typetrans->{$meta->[1]})) {
		my $class = $typetrans->{$meta->[1]};
		if (defined($transform->{$meta->[1]}->{in})) {
    		my $function = $transform->{$meta->[1]}->{in};
    		$data = $self->$function($data,$meta);
    		if (ref($data) eq "HASH") {
    			$data = $class->new($data);
    		}
		} else {
			$data = $class->new(Bio::KBase::ObjectAPI::utilities::FROMJSON($data));
		}
		$data->wsmeta($meta);
		$data->parent($self);
		$data->_reference($meta->[2].$meta->[0]."||");
	} elsif (defined($jsontypes->{$meta->[1]})) {
		$data = Bio::KBase::ObjectAPI::utilities::FROMJSON($data);
	}
	#Stashing objects into memmory cache based on uuid and workspace address
	$self->cache()->{$meta->[4]} = [$meta,$data];
	$self->cache()->{$meta->[2].$meta->[0]} = $self->cache()->{$meta->[4]};
}

#This function downloads an object from skock if it has a shock URL
sub download_object_from_shock {
	my ($self,$meta,$data) = @_;
	if (defined($meta->[11]) && length($meta->[11]) > 0 && !defined($meta->[12])) {
		my $ua = LWP::UserAgent->new();
		my $res = $ua->get($meta->[11]."?download",Authorization => "OAuth " . $self->workspace()->{token});
		$data = $res->{_content};
	}
	return $data;
}

#This function writes data to file cache if it's been flagged for local file caching
sub write_object_to_file_cache {
	my ($self,$meta,$data) = @_;
	if (length($self->file_cache()) > 0 && defined($self->cache_targets()->{$meta->[2].$meta->[0]}) && !-e $self->file_cache()."/meta".$meta->[2].$meta->[0]) {
		if (!-d $self->file_cache()."/meta/".$meta->[2]) {
			File::Path::mkpath $self->file_cache()."/meta/".$meta->[2];
		}
		if (!-d $self->file_cache()."/data/".$meta->[2]) {
			File::Path::mkpath $self->file_cache()."/data/".$meta->[2];
		}
		Bio::KBase::ObjectAPI::utilities::PRINTFILE($self->file_cache()."/meta".$meta->[2].$meta->[0],[Bio::KBase::ObjectAPI::utilities::TOJSON($meta)]);
		Bio::KBase::ObjectAPI::utilities::PRINTFILE($self->file_cache()."/data".$meta->[2].$meta->[0],[$data]);
	}
}

#This function writes data to file cache if it's been flagged for local file caching
sub read_object_from_file_cache {
	my ($self,$ref) = @_;
	if (defined($self->cache_targets()->{$ref}) && -e $self->file_cache()."/meta".$ref) {
		my $filearray = Bio::KBase::ObjectAPI::utilities::LOADFILE($self->file_cache()."/meta".$ref);
		my $meta = Bio::KBase::ObjectAPI::utilities::FROMJSON(join("\n",@{$filearray}));
		$filearray = Bio::KBase::ObjectAPI::utilities::LOADFILE($self->file_cache()."/data".$ref);
		my $data = join("\n",@{$filearray});
		return [$meta,$data];
	}
	return undef;
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
    for (my $i=0; $i < @{$reflist}; $i++) {
    	my $refinedref = $reflist->[$i];
    	$refinedref =~ s/\/+/\//g;
    	for (my $j=0; $j < @{$listout}; $j++) {
    		if ($refinedref eq $listout->[$j]->[2].$listout->[$j]->[0]) {
    			$output->{$reflist->[$i]} = $listout->[$j];
    			$self->cache()->{$reflist->[$i]} = [$listout->[$j],$refobjhash->{$reflist->[$i]}->{object}];
		    	$self->cache()->{$listout->[$j]->[2].$listout->[$j]->[0]} = [$listout->[$j],$refobjhash->{$reflist->[$i]}->{object}];
		    	$self->cache()->{$listout->[$j]->[4]} = [$listout->[$j],$refobjhash->{$reflist->[$i]}->{object}];
		    	if ($objecthash->{$reflist->[$i]} == 1) {
		    		$self->cache()->{$reflist->[$i]}->[1]->wsmeta($listout->[$j]);
					$self->cache()->{$reflist->[$i]}->[1]->_reference($listout->[$j]->[2].$listout->[$j]->[0]."||");
		    	}
		    	last;
    		}
    	}	
    }
    return $output; 
}

sub object_from_file {
	my ($self,$filename) = @_;
	my $meta = Bio::KBase::ObjectAPI::utilities::LOADFILE($filename.".meta");
	$meta = join("\n",@{$meta});
	$meta = Bio::KBase::ObjectAPI::utilities::FROMJSON($meta);
	my $data = Bio::KBase::ObjectAPI::utilities::LOADFILE($filename.".data");
	$data = join("\n",@{$data});
	$data = Bio::KBase::ObjectAPI::utilities::FROMJSON($data);
	
	return [$meta,$data];
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
	my ($self,$object,$meta) = @_;
	return $object->export( { format => "json" } );
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
