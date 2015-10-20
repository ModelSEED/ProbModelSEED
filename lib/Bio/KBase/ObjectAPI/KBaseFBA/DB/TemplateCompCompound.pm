########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateCompCompound - This is the moose object corresponding to the KBaseFBA.TemplateCompCompound object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateCompCompound;
use Bio::KBase::ObjectAPI::BaseObject;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has templatecompartment_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has maxuptake => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has templatecompound_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has charge => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has formula => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');


# LINKS:
has templatecompartment => (is => 'rw', type => 'link(TemplateModel,compartments,templatecompartment_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_templatecompartment', clearer => 'clear_templatecompartment', isa => 'Ref', weak_ref => 1);
has templatecompound => (is => 'rw', type => 'link(TemplateModel,compounds,templatecompound_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_templatecompound', clearer => 'clear_templatecompound', isa => 'Ref', weak_ref => 1);


# BUILDERS:
sub _build_reference { my ($self) = @_;return $self->parent()->_reference().'/compcompounds/id/'.$self->id(); }
sub _build_uuid { my ($self) = @_;return $self->_reference(); }
sub _build_templatecompartment {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->templatecompartment_ref());
}
sub _build_templatecompound {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->templatecompound_ref());
}


# CONSTANTS:
sub _type { return 'KBaseFBA.TemplateCompCompound'; }
sub _module { return 'KBaseFBA'; }
sub _class { return 'TemplateCompCompound'; }
sub _top { return 0; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'templatecompartment_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'maxuptake',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'templatecompound_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'charge',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'formula',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => 0,
            'name' => 'id',
            'type' => 'Str',
            'perm' => 'rw'
          }
        ];

my $attribute_map = {templatecompartment_ref => 0, maxuptake => 1, templatecompound_ref => 2, charge => 3, formula => 4, id => 5};
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
            'parent' => 'TemplateModel',
            'name' => 'templatecompartment',
            'attribute' => 'templatecompartment_ref',
            'clearer' => 'clear_templatecompartment',
            'class' => 'TemplateModel',
            'method' => 'compartments',
            'module' => undef,
            'field' => 'id'
          },
          {
            'parent' => 'TemplateModel',
            'name' => 'templatecompound',
            'attribute' => 'templatecompound_ref',
            'clearer' => 'clear_templatecompound',
            'class' => 'TemplateModel',
            'method' => 'compounds',
            'module' => undef,
            'field' => 'id'
          }
        ];

my $link_map = {templatecompartment => 0, templatecompound => 1};
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

my $subobjects = [];

my $subobject_map = {};
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
__PACKAGE__->meta->make_immutable;
1;
