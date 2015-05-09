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
my $jsontypes = {
	
};

#***********************************************************************************************************
# ATTRIBUTES:
#***********************************************************************************************************
has workspace => ( is => 'rw', isa => 'Ref', required => 1);
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
	for (my $i=0; $i < @{$refs}; $i++) {
		if (!defined($self->cache()->{$refs->[$i]}) || defined($options->{refreshcache})) {
    		push(@{$newrefs},$refs->[$i]);
    	}
	}
	#Pulling objects from workspace
	if (@{$newrefs} > 0) {
		my $objdatas = $self->workspace()->get({objects => $newrefs});
		my $object;
		for (my $i=0; $i < @{$objdatas}; $i++) {
			$self->cache()->{$objdatas->[$i]->[0]->[4]} = $objdatas->[$i];
			if (defined($typetrans->{$objdatas->[$i]->[0]->[1]})) {
				my $class = $typetrans->{$objdatas->[$i]->[0]->[1]};
				$self->cache()->{$objdatas->[$i]->[0]->[4]}->[1] = $class->new(Bio::KBase::ObjectAPI::utilities::FROMJSON($self->cache()->{$objdatas->[$i]->[0]->[4]}->[1]));
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
    		push(@{$input->{objects}},[$ref,$obj->{type},$obj->{usermeta},$obj->{object}->toJSON()]);
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

no Moose;
__PACKAGE__->meta->make_immutable;
1;
