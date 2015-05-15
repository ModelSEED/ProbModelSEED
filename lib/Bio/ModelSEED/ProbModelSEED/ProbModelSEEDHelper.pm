package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
use strict;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

use File::Path;
use File::Copy ("cp","mv");
use File::stat;
use Fcntl ':mode';
use Data::UUID;
use Bio::P3::Workspace::WorkspaceClientExt;
use JSON::XS;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use Config::Simple;
use Bio::KBase::AuthToken;
use Bio::KBase::ObjectAPI::utilities;
use Bio::KBase::ObjectAPI::PATRICStore;

Log::Log4perl->easy_init($DEBUG);

#****************************************************************************
#Getter setters for parameters
#****************************************************************************
sub workspace_url {
	my ($self,$url) = @_;
	if (defined($url)) {
		$self->{_params}->{"workspace-url"} = $url;
	}
	return $self->{_params}->{"workspace-url"};
}
sub admin_mode {
	my ($self,$adminmode) = @_;
	if (defined($adminmode)) {
		$self->PATRICStore()->adminmode($adminmode);
	}
	return $self->PATRICStore()->adminmode();
}

#****************************************************************************
#Authentication functions
#****************************************************************************
sub authenticate_token {
	my($self) = @_;
    my $token = Bio::KBase::AuthToken->new(ignore_authrc => ($ENV{KB_INTERACTIVE} ? 0 : 1));
    if ($token->validate()){
		$self->{_authenticated} = 1;
		$self->{_user_id} = $token->user_id;
		$self->{_token} = $token->token;
		Bio::KBase::ObjectAPI::utilities::token($self->{_token});
    } else {
		$self->error("Token did not validate\n" . Dumper($token));
	}
}
sub get_username {
	my ($self) = @_;
	return $self->{_user_id};
}
#****************************************************************************
#Workspace interaction functions
#****************************************************************************
sub save_object {
	my($self, $ref,$data,$type,$metadata) = @_;
	my $object = $self->PATRICStore()->save_object($data,$ref,$metadata,$type,1);
}
sub get_object {
	my($self, $ref,$type) = @_;
	my $object = $self->PATRICStore()->get_object($ref);
	my $meta = $self->PATRICStore()->object_meta($ref);
	if (defined($type) && $meta->[1] ne $type) {
		$self->error("Type retrieved (".$meta->[1].") does not match specified type (".$type.")!");
	}
	return $object;
}
sub get_model {
	my($self, $ref) = @_;
	my $model = $self->get_object($ref);
    if (defined($model) && ref($model) ne "Bio::KBase::ObjectAPI::KBaseFBA::FBAModel" && defined($model->{output_files})) {
    	my $output = $model->{output_files};
    	for (my $i=0; $i < @{$model->{output_files}}; $i++) {
    		if ($model->{output_files}->[$i]->[0] =~ m/\.model$/) {
    			$ref = $model->{output_files}->[$i]->[0];
    		}
    	}
    	$model = $self->get_object($ref,"model");
    }
    if (!defined($model)) {
    	$self->error("Model retrieval failed!");
    }
	return $model;
}
sub get_model_meta {
	my($self, $ref) = @_;
	my $metas = $self->workspace_service()->get({
		objects => [$ref],
		metadata_only => 1
	});
	if ($metas->[0]->[0]->[1] ne "model") {
		$metas = $self->workspace_service()->get({
			objects => [$metas->[0]->[0]->[2].".".$metas->[0]->[0]->[0]."/".$metas->[0]->[0]->[0].".model"],
			metadata_only => 1
		});
	}
    if (!defined($metas->[0])) {
    	$self->error("Model retrieval failed!");
    }
	return $metas->[0]->[0];
}
sub workspace_service {
	my($self) = @_;
	if (!defined($self->{_workspace_service})) {
		$self->{_workspace_service} =Bio::P3::Workspace::WorkspaceClientExt->new($self->workspace_url());
	}
	return $self->{_workspace_service};
}
sub PATRICStore {
	my($self) = @_;
	if (!defined($self->{_PATRICStore})) {
		$self->{_PATRICStore} = Bio::KBase::ObjectAPI::PATRICStore->new({workspace => $self->workspace_service()});
	}
	return $self->{_PATRICStore};
}
#****************************************************************************
#Utility functions
#****************************************************************************
sub validate_args {
	my ($self,$args,$mandatoryArguments,$optionalArguments,$substitutions) = @_;
	$self->{_adminmode} = 0;
	if (!defined($args)) {
	    $args = {};
	}
	if (ref($args) ne "HASH") {
		$self->error("Arguments not hash");
	}
	if (defined($args->{adminmode}) && $args->{adminmode} == 1) {
		if ($self->_user_is_admin() == 0) {
			$self->error("Cannot run functions in admin mode. User is not an admin!");
		}
		$self->{_adminmode} = 1;
	}
	if (defined($substitutions) && ref($substitutions) eq "HASH") {
		foreach my $original (keys(%{$substitutions})) {
			$args->{$original} = $args->{$substitutions->{$original}};
		}
	}
	if (defined($mandatoryArguments)) {
		for (my $i=0; $i < @{$mandatoryArguments}; $i++) {
			if (!defined($args->{$mandatoryArguments->[$i]})) {
				push(@{$args->{_error}},$mandatoryArguments->[$i]);
			}
		}
	}
	if (defined($args->{_error})) {
		$self->error("Mandatory arguments ".join("; ",@{$args->{_error}})." missing.");
	}
	if (defined($optionalArguments)) {
		foreach my $argument (keys(%{$optionalArguments})) {
			if (!defined($args->{$argument})) {
				$args->{$argument} = $optionalArguments->{$argument};	
			}
		}
	}
	return $args;
}
sub error {
	my($self,$msg,$type) = @_;
	if (!defined($type)) {
		$type = "Unspecified";
	}
	Bio::KBase::ObjectAPI::utilities::error($self->{_current_method}.":".$msg);
}
#****************************************************************************
#Research functions
#****************************************************************************
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
=head3 retreive_reference_genome

Definition:
	Genome = $self->retreive_reference_genome(string genome);
Description:
	Returns typed object for genome in PATRIC reference database
		
=cut
sub retreive_reference_genome {
	my($self, $genome) = @_;
	my $gto = {
		
	};
	return $gto;
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
	$fba->parent($self->PATRICStore());
	foreach my $term (@{$params->{objective}}) {
		if ($term->[0] eq "flux" || $term->[0] eq "reactionflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForReaction($term->[1]);
			if (!defined($obj)) {
				$self->_error("Reaction ".$term->[1]." not found!");
			}
			$fba->reactionflux_objterms()->{$obj->id()} = $term->[2];
		} elsif ($term->[0] eq "compoundflux" || $term->[0] eq "drainflux") {
			$term->[0] = "drainflux";
			my $obj = $model->searchForCompound($term->[1]);
			if (!defined($obj)) {
				$self->_error("Compound ".$term->[1]." not found!");
			}
			$fba->compoundflux_objterms()->{$obj->id()} = $term->[2];
		} elsif ($term->[0] eq "biomassflux") {
			my $obj = $model->searchForBiomass($term->[1]);
			if (!defined($obj)) {
				$self->_error("Biomass ".$term->[1]." not found!");
			}
			$fba->biomassflux_objterms()->{$obj->id()} = $term->[2];
		} else {
			$self->_error("Objective variable type ".$term->[0]." not recognized!");
		}
	}
	foreach my $term (@{$params->{custom_bounds}}) {
		if ($term->[0] eq "flux" || $term->[0] eq "reactionflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForReaction($term->[1]);
			if (!defined($obj)) {
				$self->_error("Reaction ".$term->[1]." not found!");
			}
			$fba->add("FBAReactionBounds",{modelreaction_ref => $obj->_reference(),variableType=> $term->[0],upperBound => $term->[2],lowerBound => $term->[3]});
		} elsif ($term->[0] eq "compoundflux" || $term->[0] eq "drainflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForCompound($term->[1]);
			if (!defined($obj)) {
				$self->_error("Compound ".$term->[1]." not found!");
			}
			$fba->add("FBACompoundBounds",{modelcompound_ref => $obj->_reference(),variableType=> $term->[0],upperBound => $term->[2],lowerBound => $term->[3]});
		} else {
			$self->_error("Objective variable type ".$term->[0]." not recognized!");
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
	return $fba;
}
#****************************************************************************
#Constructor
#****************************************************************************
sub new {
    my($class, @args) = @_;
    my $self = {};
    bless $self, $class;
    my $params = $args[0];
    my $paramlist = [qw(
    	authentication
    	username
    	fbajobcache
    	awe-url
    	shock-url
    	fbajobdir
    	mfatoolkitbin
		probanno-url
		mssserver-url
		workspace-url
    )];
    if ((my $e = $ENV{KB_DEPLOYMENT_CONFIG}) && -e $ENV{KB_DEPLOYMENT_CONFIG}) {
		my $service = $ENV{KB_SERVICE_NAME};
		if (!defined($service)) {
			$service = "ProbModelSEED";
		}
		if (defined($service)) {
			my $c = Config::Simple->new();
			$c->read($e);
			for my $p (@{$paramlist}) {
			  	my $v = $c->param("$service.$p");
			    if ($v && !defined($params->{$p})) {
					$params->{$p} = $v;
					if ($v eq "null") {
						$params->{$p} = undef;
					}
			    }
			}
		}
    }
	$params = $self->validate_args($params,[],{
		"workspace-url" => "http://p3.theseed.org/services/Workspace"
	});
	$self->{_params} = $params;
	if (defined($params->{mfatoolkitbin})) {
		Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_BINARY($params->{mfatoolkitbin});
	}
	if (defined($params->{fbajobdir})) {
		Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY($params->{fbajobdir});
	}
	if (defined($params->{fbajobcache})) {
		Bio::KBase::ObjectAPI::utilities::FinalJobCache($params->{fbajobcache});
	}
	if (!defined($params->{authentication})) {
		$self->authenticate_token();
	}
    return $self;
}

1;
