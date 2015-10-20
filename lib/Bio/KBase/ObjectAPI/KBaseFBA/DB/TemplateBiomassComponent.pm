########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateBiomassComponent - This is the moose object corresponding to the KBaseFBA.TemplateBiomassComponent object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateBiomassComponent;
use Bio::KBase::ObjectAPI::BaseObject;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has linked_compound_refs => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub {return [];}, type => 'attribute', metaclass => 'Typed');
has coefficient => (is => 'rw', isa => 'Num', printOrder => '4', default => '1', type => 'attribute', metaclass => 'Typed');
has link_coefficients => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub {return [];}, type => 'attribute', metaclass => 'Typed');
has templatecompcompound_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has class => (is => 'rw', isa => 'Str', printOrder => '1', default => '0', type => 'attribute', metaclass => 'Typed');
has coefficientType => (is => 'rw', isa => 'Str', printOrder => '3', default => '0', type => 'attribute', metaclass => 'Typed');


# LINKS:
has linked_compounds => (is => 'rw', type => 'link(TemplateModel,compcompounds,linked_compound_refs)', metaclass => 'Typed', lazy => 1, builder => '_build_linked_compounds', clearer => 'clear_linked_compounds', isa => 'ArrayRef');
has templatecompcompound => (is => 'rw', type => 'link(TemplateModel,compcompounds,templatecompcompound_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_templatecompcompound', clearer => 'clear_templatecompcompound', isa => 'Ref', weak_ref => 1);


# BUILDERS:
sub _build_linked_compounds {
	 my ($self) = @_;
	 return $self->getLinkedObjectArray($self->linked_compound_refs());
}
sub _build_templatecompcompound {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->templatecompcompound_ref());
}


# CONSTANTS:
sub _type { return 'KBaseFBA.TemplateBiomassComponent'; }
sub _module { return 'KBaseFBA'; }
sub _class { return 'TemplateBiomassComponent'; }
sub _top { return 0; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'linked_compound_refs',
            'default' => 'sub {return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 4,
            'name' => 'coefficient',
            'default' => '1',
            'type' => 'Num',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'link_coefficients',
            'default' => 'sub {return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'templatecompcompound_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 1,
            'name' => 'class',
            'default' => '0',
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 3,
            'name' => 'coefficientType',
            'default' => '0',
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          }
        ];

my $attribute_map = {linked_compound_refs => 0, coefficient => 1, link_coefficients => 2, templatecompcompound_ref => 3, class => 4, coefficientType => 5};
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
            'name' => 'linked_compounds',
            'attribute' => 'linked_compound_refs',
            'array' => 1,
            'clearer' => 'clear_linked_compounds',
            'class' => 'TemplateModel',
            'method' => 'compcompounds',
            'module' => undef,
            'field' => 'id'
          },
          {
            'parent' => 'TemplateModel',
            'name' => 'templatecompcompound',
            'attribute' => 'templatecompcompound_ref',
            'clearer' => 'clear_templatecompcompound',
            'class' => 'TemplateModel',
            'method' => 'compcompounds',
            'module' => undef,
            'field' => 'id'
          }
        ];

my $link_map = {linked_compounds => 0, templatecompcompound => 1};
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
