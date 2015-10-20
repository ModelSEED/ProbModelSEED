########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateReaction - This is the moose object corresponding to the KBaseFBA.TemplateReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
########################################################################
package Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateReaction;
use Bio::KBase::ObjectAPI::BaseObject;
use Bio::KBase::ObjectAPI::KBaseFBA::TemplateReactionReagent;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::BaseObject';


# PARENT:
has parent => (is => 'rw', isa => 'Ref', weak_ref => 1, type => 'parent', metaclass => 'Typed');
# ATTRIBUTES:
has uuid => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_uuid');
has _reference => (is => 'rw', lazy => 1, isa => 'Str', type => 'msdata', metaclass => 'Typed',builder => '_build_reference');
has GapfillDirection => (is => 'rw', isa => 'Str', printOrder => '-1', default => '=', type => 'attribute', metaclass => 'Typed');
has base_cost => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has templatecompartment_ref => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has reaction_ref => (is => 'rw', isa => 'Str', printOrder => '-1', required => 1, type => 'attribute', metaclass => 'Typed');
has direction => (is => 'rw', isa => 'Str', printOrder => '1', type => 'attribute', metaclass => 'Typed');
has maxforflux => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has reference => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has forward_penalty => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has id => (is => 'rw', isa => 'Str', printOrder => '0', required => 1, type => 'attribute', metaclass => 'Typed');
has maxrevflux => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has templatecomplex_refs => (is => 'rw', isa => 'ArrayRef', printOrder => '-1', default => sub {return [];}, type => 'attribute', metaclass => 'Typed');
has reverse_penalty => (is => 'rw', isa => 'Num', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has name => (is => 'rw', isa => 'Str', printOrder => '-1', type => 'attribute', metaclass => 'Typed');
has type => (is => 'rw', isa => 'Str', printOrder => '1', type => 'attribute', metaclass => 'Typed');


# SUBOBJECTS:
has templateReactionReagents => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { return []; }, type => 'child(TemplateReactionReagent)', metaclass => 'Typed', reader => '_templateReactionReagents', printOrder => '-1');


# LINKS:
has templatecompartment => (is => 'rw', type => 'link(TemplateModel,compartments,templatecompartment_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_templatecompartment', clearer => 'clear_templatecompartment', isa => 'Ref', weak_ref => 1);
has reaction => (is => 'rw', type => 'link(,,reaction_ref)', metaclass => 'Typed', lazy => 1, builder => '_build_reaction', clearer => 'clear_reaction', isa => 'Ref', weak_ref => 1);
has templatecomplexs => (is => 'rw', type => 'link(TemplateModel,complexes,templatecomplex_refs)', metaclass => 'Typed', lazy => 1, builder => '_build_templatecomplexs', clearer => 'clear_templatecomplexs', isa => 'ArrayRef');


# BUILDERS:
sub _build_reference { my ($self) = @_;return $self->parent()->_reference().'/reactions/id/'.$self->id(); }
sub _build_uuid { my ($self) = @_;return $self->_reference(); }
sub _build_templatecompartment {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->templatecompartment_ref());
}
sub _build_reaction {
	 my ($self) = @_;
	 return $self->getLinkedObject($self->reaction_ref());
}
sub _build_templatecomplexs {
	 my ($self) = @_;
	 return $self->getLinkedObjectArray($self->templatecomplex_refs());
}


# CONSTANTS:
sub _type { return 'KBaseFBA.TemplateReaction'; }
sub _module { return 'KBaseFBA'; }
sub _class { return 'TemplateReaction'; }
sub _top { return 0; }

my $attributes = [
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'GapfillDirection',
            'default' => '=',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'base_cost',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'templatecompartment_ref',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 1,
            'printOrder' => -1,
            'name' => 'reaction_ref',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 1,
            'name' => 'direction',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'maxforflux',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'reference',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'forward_penalty',
            'type' => 'Num',
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
            'req' => 0,
            'printOrder' => -1,
            'name' => 'maxrevflux',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'templatecomplex_refs',
            'default' => 'sub {return [];}',
            'type' => 'ArrayRef',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'reverse_penalty',
            'type' => 'Num',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => -1,
            'name' => 'name',
            'type' => 'Str',
            'perm' => 'rw'
          },
          {
            'req' => 0,
            'printOrder' => 1,
            'name' => 'type',
            'default' => undef,
            'type' => 'Str',
            'description' => undef,
            'perm' => 'rw'
          }
        ];

my $attribute_map = {GapfillDirection => 0, base_cost => 1, templatecompartment_ref => 2, reaction_ref => 3, direction => 4, maxforflux => 5, reference => 6, forward_penalty => 7, id => 8, maxrevflux => 9, templatecomplex_refs => 10, reverse_penalty => 11, name => 12, type => 13};
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
            'parent' => undef,
            'name' => 'reaction',
            'attribute' => 'reaction_ref',
            'clearer' => 'clear_reaction',
            'class' => undef,
            'method' => undef,
            'module' => undef,
            'field' => undef
          },
          {
            'parent' => 'TemplateModel',
            'name' => 'templatecomplexs',
            'attribute' => 'templatecomplex_refs',
            'array' => 1,
            'clearer' => 'clear_templatecomplexs',
            'class' => 'TemplateModel',
            'method' => 'complexes',
            'module' => undef,
            'field' => 'id'
          }
        ];

my $link_map = {templatecompartment => 0, reaction => 1, templatecomplexs => 2};
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
            'name' => 'templateReactionReagents',
            'type' => 'child',
            'class' => 'TemplateReactionReagent',
            'module' => 'KBaseFBA'
          }
        ];

my $subobject_map = {templateReactionReagents => 0};
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
around 'templateReactionReagents' => sub {
	 my ($orig, $self) = @_;
	 return $self->_build_all_objects('templateReactionReagents');
};


__PACKAGE__->meta->make_immutable;
1;
