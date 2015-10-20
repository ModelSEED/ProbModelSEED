########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelTemplate - This is the moose object corresponding to the KBaseFBA.ModelTemplate object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseFBA::DB::ModelTemplate;
use Bio::KBase::ObjectAPI::IndexedObject;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplatePathway;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateRole;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateBiomass;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateCompound;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateReaction;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateComplex;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateCompartment;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateCompCompound;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::IndexedObject';


our $VERSION = 1.0;
# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has biochemistry_ref => (is => 'rw', isa => 'Str', printOrder => '-1', default => 'kbase/default', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', printOrder => '1', required => 1, type => 'attribute', metaclass => 'Typed');
has domain => (is => 'rw', isa => 'Str', printOrder => '2', required => 1, type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has modelType => (is => 'rw', isa => 'Str', printOrder => '1', required => 1, type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has pathways => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplatePathway)', metaclass => 'Typed', reader => '_pathways', printOrder => '-1');
has roles => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateRole)', metaclass => 'Typed', reader => '_roles', printOrder => '-1');
has biomasses => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateBiomass)', metaclass => 'Typed', reader => '_biomasses', printOrder => '-1');
has compounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateCompound)', metaclass => 'Typed', reader => '_compounds', printOrder => '-1');
has reactions => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateReaction)', metaclass => 'Typed', reader => '_reactions', printOrder => '-1');
has complexes => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateComplex)', metaclass => 'Typed', reader => '_complexes', printOrder => '-1');
has compartments => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateCompartment)', metaclass => 'Typed', reader => '_compartments', printOrder => '-1');
has compcompounds => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateCompCompound)', metaclass => 'Typed', reader => '_compcompounds', printOrder => '-1');


# LINKS:
has biochemistry => (is => 'rw', type => 'link(Bio::KBase::ObjectAPI::KBaseStore,Biochemistry,biochemistry_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_biochemistry', clearer => 'clear_biochemistry', isa => 'Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry', weak_ref => 1);


# BUILDERS:
sub _build_reference { my ($self) = @_;return $self->uuid(); }
sub _build_uuid { return Data::UUID->new()->create_str(); }
sub _build_biochemistry {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->biochemistry_ref());
}


# CONSTANTS:
sub __version__ { return $VERSION; }
sub _type { return 'KBaseFBA.ModelTemplate'; }
sub _module { return 'KBaseFBA'; }
sub _class { return 'ModelTemplate'; }
sub _top { return 1; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'biochemistry_ref',
            'default' => 'kbase/default',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 1,
            'name' => 'name',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 2,
            'name' => 'domain',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'id',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 1,
            'name' => 'modelType',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          }
        ];

my $attribute_map = {biochemistry_ref => 0, name => 1, domain => 2, id => 3, modelType => 4};
sub _attributes {
	 my ($self, $key) = @_;
	 if (defined($key)) {
	 	 my $ind = $attribute_map->{$key};
	 	 if (defined($ind)) {
	 	 	 return $attributes->[$ind];
	 	 } else {
	 	 	 return;
	 	 }
	 } else {
	 	 return $attributes;
	 }
}

my $links = [
          {
            'attribute' => 'biochemistry_ref',
            'parent' => 'Bio::KBase::ObjectAPI::KBaseStore',
            'clearer' => 'clear_biochemistry',
            'name' => 'biochemistry',
            'method' => 'Biochemistry',
            'class' => 'Bio::KBase::ObjectAPI::KBaseBiochem::Biochemistry',
            'module' => 'KBaseBiochem'
          }
        ];

my $link_map = {biochemistry => 0};
sub _links {
	 my ($self, $key) = @_;
	 if (defined($key)) {
	 	 my $ind = $link_map->{$key};
	 	 if (defined($ind)) {
	 	 	 return $links->[$ind];
	 	 } else {
	 	 	 return;
	 	 }
	 } else {
	 	 return $links;
	 }
}

my $subobjects = [
          {
            'printOrder' => -1,
            'name' => 'pathways',
            'type' => 'child',
            'class' => 'TemplatePathway',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'roles',
            'type' => 'child',
            'class' => 'TemplateRole',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'biomasses',
            'type' => 'child',
            'class' => 'TemplateBiomass',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'compounds',
            'type' => 'child',
            'class' => 'TemplateCompound',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'reactions',
            'type' => 'child',
            'class' => 'TemplateReaction',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'complexes',
            'type' => 'child',
            'class' => 'TemplateComplex',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'compartments',
            'type' => 'child',
            'class' => 'TemplateCompartment',
            'module' => 'KBaseFBA'
          },
          {
            'printOrder' => -1,
            'name' => 'compcompounds',
            'type' => 'child',
            'class' => 'TemplateCompCompound',
            'module' => 'KBaseFBA'
          }
        ];

my $subobject_map = {pathways => 0, roles => 1, biomasses => 2, compounds => 3, reactions => 4, complexes => 5, compartments => 6, compcompounds => 7};
sub _subobjects {
	 my ($self, $key) = @_;
	 if (defined($key)) {
	 	 my $ind = $subobject_map->{$key};
	 	 if (defined($ind)) {
	 	 	 return $subobjects->[$ind];
	 	 } else {
	 	 	 return;
	 	 }
	 } else {
	 	 return $subobjects;
	 }
}
# SUBOBJECT READERS:
around 'pathways' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('pathways');
};
around 'roles' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('roles');
};
around 'biomasses' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('biomasses');
};
around 'compounds' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('compounds');
};
around 'reactions' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('reactions');
};
around 'complexes' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('complexes');
};
around 'compartments' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('compartments');
};
around 'compcompounds' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('compcompounds');
};


__PACKAGE__->meta->make_immutable;
1;
