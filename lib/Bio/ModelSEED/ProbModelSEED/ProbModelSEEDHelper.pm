package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
use strict;
use Bio::ModelSEED::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

use File::Path;
use File::Copy ("cp","mv");
use File::stat;
use Fcntl ':mode';
use Data::UUID;
use REST::Client;
use Bio::P3::Workspace::WorkspaceClient;
use JSON::XS;
use Data::Dumper;
use HTTP::Request::Common;
use Log::Log4perl qw(:easy);
use MongoDB::Connection;
use URI::Escape;
use AnyEvent;
use AnyEvent::HTTP;
use Config::Simple;
use Bio::KBase::AuthToken;
use Bio::KBase::ObjectAPI::utilities;
use Bio::KBase::ObjectAPI::PATRICStore;

Log::Log4perl->easy_init($DEBUG);

#Returns the authentication token supplied to the service in the context object
sub authenticate_token {
	my($self) = @_;
    my $token = Bio::KBase::AuthToken->new(ignore_authrc => ($ENV{KB_INTERACTIVE} ? 0 : 1));
    if ($token->validate()){
		$self->{_authenticated} = 1;
		$self->{_user_id} = $token->user_id;
		$self->{_token} = $token->token;
		Bio::KBase::ObjectAPI::utilities::token($self->{_token});
    } else {
		warn "Token did not validate\n" . Dumper($token);
	}
}

#Returns the username supplied to the service in the context object
sub get_username {
	my ($self) = @_;
	return $self->{_user_id};
}

sub workspace_url {
	my ($self) = @_;
	return $self->{_params}->{"workspace-url"};
}

#Validating arguments checking on mandatory values and filling in default values
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

#Throw an exception with the specified type and message
sub error {
	my($self,$msg,$type) = @_;
	if (!defined($type)) {
		$type = "Unspecified";
	}
	die $self->{_current_method}.":".$msg;
}

=head3 _classify_genome

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

=head3 _genome_to_model

Definition:
	Bio::KBase::ObjectAPI::KBaseFBA::FBAModel = $self->_genome_to_model(Bio::KBase::ObjectAPI::KBaseGenomes::Genome);
Description:
	Builds model from genome
		
=cut
sub _genome_to_model {
	my($self,$genome,$mdlid,$params) = @_;
    #Retrieving template model
    my $template;
    if (defined($params->{templatemodel})) {
    	$template = $self->_get_msobject("ModelTemplate",$params->{templatemodel_workspace},$params->{templatemodel});
    } elsif ($params->{coremodel} == 1) {
    	$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","CoreModelTemplate");
    } elsif ($genome->domain() eq "Plant" || $genome->taxonomy() =~ /viridiplantae/i) {
    	$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","PlantModelTemplate");
	} else {
		my $features = {};
		my $genes = $genome->features();
		for (my $i=0; $i < @{$genes}; $i++) {
			$features->{$genes->[$i]} = $genes->roles();
		}
		my $class = $self->_classify_genome($features);
		if ($class eq "Gram positive") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramPosModelTemplate");
    	} elsif ($class eq "Gram negative") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramNegModelTemplate");
    	} elsif ($class eq "Plant") {
    		$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","PlantModelTemplate");
    	}
    }
    if (!defined($template)) {
    	$template = $self->_get_msobject("ModelTemplate","KBaseTemplateModels","GramPosModelTemplate");
    }
    #Building the model
    my $mdl = $template->buildModel({
	    genome => $genome,
	    modelid => $mdlid,
	    fulldb => $params->{fulldb}
	});
	return $mdl;
}

sub retreive_reference_genome {
	my($self, $genome) = @_;
	my $gto = {
		
	};
	return $gto;
}

sub save_object {
	my($self, $ref,$data,$type) = @_;
	my $object = $self->PATRICStore()->save_object($data,$ref,{},$type,1);
}

sub get_object {
	my($self, $ref,$type) = @_;
	my $object = $self->PATRICStore()->get_object($ref);
	my $meta = $self->PATRICStore()->object_meta($ref);
	if ($meta->[1] ne $type) {
		$self->error("Type retrieved (".$meta->[1].") does not match specified type (".$type.")!");
	}
	return $object;
}

sub PATRICStore {
	my($self) = @_;
	return $self->{_PATRICStore};
}

sub new {
    my($class, @args) = @_;
    my $self = {};
    bless $self, $class;
    my $params = $args[0];
    my $paramlist = [qw(
    	adminmode
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
		adminmode => 0,
		"workspace-url" => "http://p3.theseed.org/services/Workspace"
	});
	if (defined($params->{mfatoolkitbin})) {
		Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_BINARY($params->{mfatoolkitbin});
	}
	if (defined($params->{fbajobdir})) {
		Bio::KBase::ObjectAPI::utilities::MFATOOLKIT_JOB_DIRECTORY($params->{fbajobdir});
	}
	if (defined($params->{fbajobcache})) {
		Bio::KBase::ObjectAPI::utilities::FinalJobCache($params->{fbajobcache});
	}
	my $ws = Bio::P3::Workspace::WorkspaceClientExt->new($params->{"workspace-url"});
	$self->{_PATRICStore} = Bio::KBase::ObjectAPI::PATRICStore->new({workspace => $ws});
	$self->{_PATRICStore}->adminmode($params->{adminmode});
	$self->{_params} = $params;
	$self->authenticate_token();
    return $self;
}

1;
