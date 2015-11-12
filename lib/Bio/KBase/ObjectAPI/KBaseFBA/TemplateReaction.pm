########################################################################
# Bio::KBase::ObjectAPI::KBaseFBA::TemplateReaction - This is the moose object corresponding to the TemplateReaction object
# Authors: Christopher Henry, Scott Devoid, Paul Frybarger
# Contact email: chenry@mcs.anl.gov
# Development location: Mathematics and Computer Science Division, Argonne National Lab
# Date of module creation: 2013-04-26T05:53:23
########################################################################
use strict;
use Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateReaction;
package Bio::KBase::ObjectAPI::KBaseFBA::TemplateReaction;
use Moose;
use namespace::autoclean;
extends 'Bio::KBase::ObjectAPI::KBaseFBA::DB::TemplateReaction';
use Bio::KBase::ObjectAPI::utilities;
#***********************************************************************************************************
# ADDITIONAL ATTRIBUTES:
#***********************************************************************************************************
has complexIDs => ( is => 'rw', isa => 'ArrayRef',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildcomplexIDs' );
has isBiomassTransporter => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildisBiomassTransporter' );
has inSubsystem => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildinSubsystem' );
has msid => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmsid' );
has msname => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmsname' );
has msabbreviation => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildmsabbreviation' );
has isTransporter => ( is => 'rw', isa => 'Bool',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildisTransporter' );

has reaction_ref => ( is => 'rw', isa => 'Str',printOrder => '-1', type => 'msdata', metaclass => 'Typed', lazy => 1, builder => '_buildreaction_ref' );

#***********************************************************************************************************
# BUILDERS:
#***********************************************************************************************************
sub _buildreaction_ref {
	my ($self) = @_;
	my $array = [split(/_/,$self->id())];
	return $self->parent()->biochemistry_ref()."/reactions/id/".$array->[0];
}
sub _buildmsid {
	my ($self) = @_;
	my $array = [split(/_/,$self->id())];
	return $array->[0];
}
sub _buildmsname {
	my ($self) = @_;
	my $array = [split(/_/,$self->name())];
	return $array->[0];
}
sub _buildmsabbreviation {
	my ($self) = @_;
	my $array = [split(/_/,$self->abbreviation())];
	return $array->[0];
}
sub _buildcomplexIDs {
	my ($self) = @_;
	my $output = [];
	my $cpxs = $self->templatecomplexs();
	for (my $i=0; $i <@{$cpxs}; $i++) {
		my $cpx = $cpxs->[$i];
		push(@{$output},$cpx->id());
	}
	return $output;
}
sub _buildisBiomassTransporter {
	my ($self) = @_;
	my $rgts = $self->templateReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if ($rgt->templatecompcompound()->isBiomassCompound() == 1) {
			for (my $j=$i+1; $j < @{$rgts}; $j++) {
				my $rgtc = $rgts->[$j];
				if ($rgt->templatecompcompound()->templatecompound_ref() eq $rgtc->templatecompcompound()->templatecompound_ref()) {
					if ($rgt->templatecompcompound()->templatecompartment_ref() ne $rgtc->templatecompcompound()->templatecompartment_ref()) {
						return 1;
					}
				}
			}
		}
	}
	return 0;
}
sub _buildinSubsystem {
	my ($self) = @_;
	my $rolesshash = $self->parent()->roleSubsystemHash();
	my $complexes = $self->templatecomplexs();
	foreach my $complex (@{$complexes}) {
		my $cpxroles = $complex->complexroles();
		foreach my $cpxrole (@{$cpxroles}) {
			my $role = $cpxrole->templaterole();
			if (defined($rolesshash->{$role->id()})) {
				return 1;
			}
		}
	}
	return 0;
}
sub _buildisTransporter {
	my ($self) = @_;
	my $rgts = $self->templateReactionReagents();
	my $initrgt = $rgts->[0];
	for (my $i=1; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		if ($rgt->templatecompcompound()->templatecompartment_ref() ne $initrgt->templatecompcompound()->templatecompartment_ref()) {
			return 1;	
		}
	}
	return 0;
}

#***********************************************************************************************************
# CONSTANTS:
#***********************************************************************************************************

#***********************************************************************************************************
# FUNCTIONS:
#***********************************************************************************************************
sub compute_penalties {
	my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args([],{
		no_KEGG_penalty => 1,
		no_KEGG_map_penalty => 1,
		functional_role_penalty => 2,
		subsystem_penalty => 1,
		transporter_penalty => 1,
		unknown_structure_penalty => 1,
		biomass_transporter_penalty => 1,
		single_compound_transporter_penalty => 1,
		direction_penalty => 1,
		unbalanced_penalty => 10,
		no_delta_G_penalty => 1
	}, @_);
	my $thermopenalty = 0; 
	my $coefficient = 1;
	if (!defined($self->reaction()->getAlias("KEGG"))) {
		$coefficient += $args->{no_KEGG_penalty};
		$coefficient += $args->{no_KEGG_map_penalty};
	} elsif (!defined(Bio::KBase::ObjectAPI::utilities::KEGGMapHash()->{$self->reaction()->id()})) {
		$coefficient += $args->{no_KEGG_map_penalty};
	}
	if (!defined($self->deltaG()) || $self->deltaG() == 10000000) {
		$coefficient += $args->{no_delta_G_penalty};
		$thermopenalty += 1.5;
	} else {
		$thermopenalty += $self->deltaG()/10;
	}
	if (@{$self->complexs()} == 0) {
		$coefficient += $args->{functional_role_penalty};
		$coefficient += $args->{subsystem_penalty};
	} elsif ($self->inSubsystem() == 1) {
		$coefficient += $args->{subsystem_penalty};
	}
	if ($self->isTransport()) {
		$coefficient += $args->{transporter_penalty};
		if (@{$self->reaction()->reagents()} <= 2) {
			$coefficient += $args->{single_compound_transporter_penalty};
		}
		if ($self->isBiomassTransporter() == 1) {
			$coefficient += $args->{biomass_transporter_penalty};
		}
	}
	if ($self->reaction()->unknownStructure()) {
		$coefficient += $args->{unknown_structure_penalty};
	}
	if ($self->reaction()->status() =~ m/[CM]I/) {
		$coefficient += $args->{unbalanced_penalty};
	}
	if ($self->reaction()->thermoReversibility() eq ">") {
		$self->forward_penalty(0);
		$self->reverse_penalty($args->{direction_penalty}+$thermopenalty);	
	} elsif ($self->reaction()->thermoReversibility() eq "<") {
		$self->reverse_penalty(0);
		$self->forward_penalty($args->{direction_penalty}+$thermopenalty);
	} else {
		$self->forward_penalty(0);
		$self->reverse_penalty(0);
	}
	$self->base_cost($coefficient);
}

sub addRxnToModel {
    my $self = shift;
	my $args = Bio::KBase::ObjectAPI::utilities::args(["role_features","model"],{
		fulldb => 0
	}, @_);
	my $mdl = $args->{model};
	#Gathering roles from annotation
	my $roleFeatures = $args->{role_features};
	my $cpxs = $self->templatecomplexs();
	my $proteins = [];
	for (my $i=0; $i < @{$cpxs}; $i++) {
		my $cpx = $cpxs->[$i];
		my $complexroles = $cpx->complexroles();
		my $present = 0;
		my $subunits;
		for (my $j=0; $j < @{$complexroles}; $j++) {
			my $cpxrole = $complexroles->[$j];
			if (defined($roleFeatures->{$cpxrole->templaterole()->id()})) {
				foreach my $compartment (keys(%{$roleFeatures->{$cpxrole->templaterole()->id()}})) {
					if ($compartment eq "u" || $compartment eq $self->compartment()->id()) {
						if ($cpxrole->triggering() == 1) {
							$present = 1;	
						}
					}
					$subunits->{$cpxrole->templaterole()->name()}->{triggering} = $cpxrole->triggering();
					$subunits->{$cpxrole->templaterole()->name()}->{optional} = $cpxrole->optional();
					if (!defined($roleFeatures->{$cpxrole->templaterole()->id()}->{$compartment}->[0])) {
						$subunits->{$cpxrole->templaterole()->name()}->{note} = "Role-based-annotation";
					} else {
						foreach my $feature (@{$roleFeatures->{$cpxrole->templaterole()->id()}->{$compartment}}) {
							$subunits->{$cpxrole->templaterole()->name()}->{genes}->{$feature->_reference()} = $feature;	
						}
					}
				}
			}
		}
		if ($present == 1) {
			for (my $j=0; $j < @{$complexroles}; $j++) {
				my $cpxrole = $complexroles->[$j];
				if ($cpxrole->optional() == 0 && !defined($subunits->{$cpxrole->templaterole()->name()})) {
					$subunits->{$cpxrole->templaterole()->name()}->{triggering} = $cpxrole->triggering();
					$subunits->{$cpxrole->templaterole()->name()}->{optional} = $cpxrole->optional();
					$subunits->{$cpxrole->templaterole()->name()}->{note} = "Complex-based-gapfilling";
				}
			}
			push(@{$proteins},{subunits => $subunits,cpx => $cpx});
		}
	}
	#Adding reaction
	if (@{$proteins} == 0 && $self->type() ne "universal" && $self->type() ne "spontaneous" && $args->{fulldb} == 0) {
		return;
	}
    my $mdlcmp = $mdl->addCompartmentToModel({compartment => $self->templatecompartment(),pH => 7,potential => 0,compartmentIndex => 0});
    my $mdlrxn = $mdl->getObject("modelreactions", $self->msid()."_".$mdlcmp->id());
    if(!$mdlrxn){
	$mdlrxn = $mdl->add("modelreactions",{
		id => $self->msid()."_".$mdlcmp->id(),
		probability => 0,
		reaction_ref => $self->_reference(),
		direction => $self->direction(),
		modelcompartment_ref => $mdlcmp->_reference(),
		modelReactionReagents => [],
		modelReactionProteins => []
	});
	my $rgts = $self->templateReactionReagents();
	for (my $i=0; $i < @{$rgts}; $i++) {
		my $rgt = $rgts->[$i];
		my $rgtcmp = $mdl->addCompartmentToModel({compartment => $rgt->templatecompcompound()->templatecompartment(),pH => 7,potential => 0,compartmentIndex => 0});
		my $coefficient = $rgt->coefficient();
		my $mdlcpd = $mdl->addCompoundToModel({
			compound => $rgt->templatecompcompound()->templatecompound(),
			modelCompartment => $rgtcmp,
		});
		$mdlrxn->addReagentToReaction({
			coefficient => $coefficient,
			modelcompound_ref => $mdlcpd->_reference()
		});
	}
    }
    if (@{$proteins} > 0 && scalar(@{$mdlrxn->modelReactionProteins()})==0) {
	foreach my $protein (@{$proteins}) {
	    $mdlrxn->addModelReactionProtein({
		proteinDataTree => $protein,
		complex_ref => $protein->{cpx}->_reference()
					     });
	}
    } elsif (scalar(@{$mdlrxn->modelReactionProteins()})==0) {
	$mdlrxn->addModelReactionProtein({
	    proteinDataTree => {note => $self->type()},
					 });
    }

    return $mdlrxn;
}



__PACKAGE__->meta->make_immutable;
1;
