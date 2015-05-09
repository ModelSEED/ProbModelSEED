package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

ProbModelSEED

=head1 DESCRIPTION

=head1 ProbModelSEED

=head2 DISTINCTIONS FROM KBASE
        All operations print their results in an output folder specified by the ouptut_loc argument.
        Functions are not as atomic. For example, model reconstruction will automatically create SBML and excel versions of model.
        Lists of essential genes will be automatically predicted. Lists of gapfilled reactions will be automatically printed into files.
        Combining workspace and ID arguments into single "ref" argument.
        Alot more output files, because not every output needs to be a typed object anymore.
        Thus functions create a folder full of output - not necessarily a single typed object.

=cut

#BEGIN_HEADER

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
use Plack::Request;
use Bio::ModelSEED::Exceptions;

Log::Log4perl->easy_init($DEBUG);

#
# Alias our context variable.
#
*Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl::CallContext = *Bio::ModelSEED::ProbModelSEED::Service::CallContext;
our $CallContext;

#Returns the authentication token supplied to the service in the context object
sub _authentication {
	my($self) = @_;
	return $CallContext->token;
}

#Returns the username supplied to the service in the context object
sub _getUsername {
	my ($self) = @_;
	return $CallContext->user_id;
}

#Indicates if user is signed in as an admin
sub _adminmode {
	my ($self) = @_;
	if (!defined($CallContext->{_adminmode})) {
		$CallContext->{_adminmode} = 0;
	}
	return $CallContext->{_adminmode};
}

#Initialization function for call
sub _initialize_call {
	my ($self,$params) = @_;
	#Setting URL for connected services
	if (defined($params->{adminmode})) {
		$CallContext->{_adminmode} = $params->{adminmode};
	}
	if (defined($params->{wsurl})) {
		$CallContext->{_wsurl} = $params->{wsurl};
	}
	if (defined($params->{probanno_url})) {
		$CallContext->{_probanno_url} = $params->{probanno_url};
	}
    Bio::ModelSEED::ProbModelSEED::utilities::token($self->_authentication());
	return $params;
}

#Returns the method supplied to the service in the context object
sub _current_method {
	my ($self) = @_;
	if (!defined($CallContext)) {
		return undef;
	}
	return $CallContext->method;
}

#Validating arguments checking on mandatory values and filling in default values
sub _validateargs {
	my ($self,$args,$mandatoryArguments,$optionalArguments,$substitutions) = @_;
	$CallContext->{_adminmode} = 0;
	if (!defined($args)) {
	    $args = {};
	}
	if (ref($args) ne "HASH") {
		$self->_error("Arguments not hash");
	}
	if (defined($args->{adminmode}) && $args->{adminmode} == 1) {
		if ($self->_user_is_admin() == 0) {
			$self->_error("Cannot run functions in admin mode. User is not an admin!");
		}
		$CallContext->{_adminmode} = 1;
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
		$self->_error("Mandatory arguments ".join("; ",@{$args->{_error}})." missing.");
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
sub _error {
	my($self,$msg,$type) = @_;
	if (!defined($type)) {
		$type = "Unspecified";
	}
	my $errorclass = "Bio::ModelSEED::Exceptions::".$type;
	$errorclass->throw(error => $msg,method_name => $self->_current_method());
}

#Creates folder with model data
sub _save_model {
	my($self,$model,$coreref) = @_;
	#Saving completed model to database
	$self->save_ms_object($coreref.".json",$model,$model->_type());
	#Saving SBML file to database
	$self->save_ms_object($coreref.".xml",$model->print_sbml(),"sbml");
	#Saving Excel file to database
	$self->save_ms_object($coreref.".xls",$model->print_excel(),"xls");
}

#Creates folder with model data
sub _get_ms_object {
	my($self,$ref,$type) = @_;
	#Saving completed model to database
	$self->save_ms_object($coreref.".json",$model,$model->_type());
	#Saving SBML file to database
	$self->save_ms_object($coreref.".xml",$model->print_sbml(),"sbml");
	#Saving Excel file to database
	$self->save_ms_object($coreref.".xls",$model->print_excel(),"xls");
}

=head3 _classify_genome

Definition:
	Genome = $self->_classify_genome(Genome genome);
Description:
	Returns the cell wall classification for genome
		
=cut
sub _classify_genome {
	my($self,$features) = @_;
	if (!defined($self->{_classifierdata})) {
	    my $data = $self->_get_ms_object("FILE:".$self->_params()->{moduledirectory}."/data/gram_classifier.txt","txt");
	    $data =~ [split(/\n/,$data)];
	    my $headings = [split(/\t/,$data->[0])];
		my $popprob = [split(/\t/,$data->[1])];
		for (my $i=1; $i < @{$headings}; $i++) {
			$self->{_classifierdata}->{classifierClassifications}->{$headings->[$i]} = {
				name => $headings->[$i],
				populationProbability => $popprob->[$i]
			};
		}
		my $cfRoleHash = {};
		for (my $i=2;$i < @{$data}; $i++) {
			my $row = [split(/\t/,$data->[$i])];
			my $searchrole = Bio::KBase::ObjectAPI::utilities::convertRoleToSearchRole($row->[0]);
			$self->{_classifierdata}->{classifierRoles}->{$searchrole} = {
				classificationProbabilities => {},
				role => $row->[0]
			};
			for (my $j=1; $j < @{$headings}; $j++) {
				$self->{_classifierdata}->{classifierRoles}->{$searchrole}->{classificationProbabilities}->{$headings->[$j]} = $row->[$j];
			}
		}
	}
	my $scores = {};
	my $sum = 0;
	foreach my $class (keys(%{$self->{_classifierdata}->{classifierClassifications}})) {
		$scores->{$class} = 0;
		$sum += $self->{_classifierdata}->{classifierClassifications}->{$class}->{populationProbability};
	}
	foreach my $gene (keys(%{$features})) {
		my $roles = [$features->{$gene}];
		foreach my $role (@{$roles}) {
			my $searchrole = Bio::KBase::ObjectAPI::utilities::convertRoleToSearchRole($role);
			if (defined($self->{_classifierdata}->{classifierRoles}->{$searchrole})) {
				foreach my $class (keys(%{$self->{_classifierdata}->{classifierClassifications}})) {
					$scores->{$class} += $self->{_classifierdata}->{classifierRoles}->{$searchrole}->{classificationProbabilities}->{$class};
				}
			}
		}
	}
	my $largest;
	my $largestClass;
	foreach my $class (keys(%{$self->{_classifierdata}->{classifierClassifications}})) {
		$scores->{$class} += log($self->{_classifierdata}->{classifierClassifications}->{$class}->{populationProbability}/$sum);
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

#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR
    my $params = $args[0];
    my $paramlist = [qw(
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
	$self->{_params} = $self->_validateargs($params,[],{
		
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
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 import_media

  $output = $obj->import_media($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an import_media_params
$output is a function_output
import_media_params is a reference to a hash where the following keys are defined:
	mediafile has a value which is a ref
	output_loc has a value which is a ref
	ouput_id has a value which is a string
	format has a value which is a mediaformat
ref is a string
mediaformat is a string
function_output is a reference to a hash where the following keys are defined:
	path has a value which is a ref
	typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
	output_files has a value which is a reference to a hash where the key is a string and the value is a string
	messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: a timestamp
	1: (class) a string
	2: (message) a string

	arguments has a value which is a string
type is a string
timestamp is a string

</pre>

=end html

=begin text

$input is an import_media_params
$output is a function_output
import_media_params is a reference to a hash where the following keys are defined:
	mediafile has a value which is a ref
	output_loc has a value which is a ref
	ouput_id has a value which is a string
	format has a value which is a mediaformat
ref is a string
mediaformat is a string
function_output is a reference to a hash where the following keys are defined:
	path has a value which is a ref
	typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
	output_files has a value which is a reference to a hash where the key is a string and the value is a string
	messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: a timestamp
	1: (class) a string
	2: (message) a string

	arguments has a value which is a string
type is a string
timestamp is a string


=end text



=item Description

Import a media formulation and map to central biochemistry database

=back

=cut

sub import_media
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to import_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_media');
    }

    my $ctx = $Bio::ModelSEED::ProbModelSEED::Server::CallContext;
    my($output);
    #BEGIN import_media
    $output = $self->initialize_call($input);
    $input = $self->_validateargs($input,["output_loc","mediafile"],{
		format => "TSV",
		output_id => undef
	});
	my $mediafile = $self->_get_ms_object($input->{mediafile},"tsv");
	my $table = Bio::ModelSEED::ProbModelSEED::utilities::parse_input_table($mediafile,"\t");
	
	
	$self->_save_ms_object($input->{output_loc}."/".$input->{output_id},$media,"media");
    #END import_media
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to import_media:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'import_media');
    }
    return($output);
}




=head2 reconstruct_fbamodel

  $output = $obj->reconstruct_fbamodel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a reconstruct_fbamodel_params
$output is a function_output
reconstruct_fbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a ref
	output_loc has a value which is a ref
	template_model has a value which is a ref
	ouput_id has a value which is a string
	coremodel has a value which is a bool
	fulldb has a value which is a bool
ref is a string
bool is an int
function_output is a reference to a hash where the following keys are defined:
	path has a value which is a ref
	typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
	output_files has a value which is a reference to a hash where the key is a string and the value is a string
	messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: a timestamp
	1: (class) a string
	2: (message) a string

	arguments has a value which is a string
type is a string
timestamp is a string

</pre>

=end html

=begin text

$input is a reconstruct_fbamodel_params
$output is a function_output
reconstruct_fbamodel_params is a reference to a hash where the following keys are defined:
	genome has a value which is a ref
	output_loc has a value which is a ref
	template_model has a value which is a ref
	ouput_id has a value which is a string
	coremodel has a value which is a bool
	fulldb has a value which is a bool
ref is a string
bool is an int
function_output is a reference to a hash where the following keys are defined:
	path has a value which is a ref
	typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
	output_files has a value which is a reference to a hash where the key is a string and the value is a string
	messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: a timestamp
	1: (class) a string
	2: (message) a string

	arguments has a value which is a string
type is a string
timestamp is a string


=end text



=item Description

Build a genome-scale metabolic model based on annotations in an input genome typed object

=back

=cut

sub reconstruct_fbamodel
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to reconstruct_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'reconstruct_fbamodel');
    }

    my $ctx = $Bio::ModelSEED::ProbModelSEED::Server::CallContext;
    my($output);
    #BEGIN reconstruct_fbamodel
    $input = $self->_validateargs($input,["genome"],{
		output_loc => undef,
		output_id => undef,
		template_model => undef,
		coremodel => 0,
		fulldb => 0,
		publicgenome => 0
	});
	$output = $self->initialize_call($input);
	my $genome;
	if ($input->{publicgenome} == 1) {
		$genome = $self->_load_genome_from_solr($input->{genome});
	} else {
		$genome = $self->_get_msobject($input->{genome},"Genome");
	}
	if (!defined($input->{output_id})) {
		$input->{output_id} = $genome->id().".model";
	}
	if (!defined($input->{output_loc})) {
		if ($input->{publicgenome} == 1) {
			$input->{output_loc} = "/".$self->_getUsername()."/home/models/".$input->{output_id};
		} else {
			$input->{output_loc} = $genome->_wspath()."/model/";
		}
	}
    my $mdl = $self->_genome_to_model($genome,$input->{output_id},$input);
	$self->_save_msobject($input->{output_loc}."/".$input->{output_id}.".model",$mdl,"model");    
    #END reconstruct_fbamodel
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to reconstruct_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'reconstruct_fbamodel');
    }
    return($output);
}




=head2 flux_balance_analysis

  $output = $obj->flux_balance_analysis($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a flux_balance_analysis_params
$output is a function_output
flux_balance_analysis_params is a reference to a hash where the following keys are defined:
	model has a value which is a ref
	output_loc has a value which is a ref
	media has a value which is a ref
	fva has a value which is a bool
	simulateko has a value which is a bool
	minimizeflux has a value which is a bool
	findminmedia has a value which is a bool
	allreversible has a value which is a bool
	thermo_const_type has a value which is a thermotype
	media_supplements has a value which is a reference to a list where each element is a string
	geneko has a value which is a reference to a list where each element is a string
	rxnko has a value which is a reference to a list where each element is a string
	output_id has a value which is a string
	maxflux has a value which is a float
	maxuptake has a value which is a float
	minuptake has a value which is a float
	primary_objective_fraction has a value which is a float
	uptakelim has a value which is a reference to a hash where the key is an atomtype and the value is a float
	custom_bounds has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: (type) a vartype
	1: (id) a string
	2: (min) a float
	3: (max) a float

	objective has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (type) a vartype
	1: (id) a string
	2: (coefficient) a float

	custom_constraints has a value which is a reference to a list where each element is a constraint
ref is a string
bool is an int
thermotype is a string
atomtype is a string
vartype is a string
constraint is a reference to a hash where the following keys are defined:
	equality has a value which is a sign
	rhs has a value which is a float
	terms has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (type) a vartype
	1: (id) a string
	2: (coefficient) a float

sign is a string
function_output is a reference to a hash where the following keys are defined:
	path has a value which is a ref
	typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
	output_files has a value which is a reference to a hash where the key is a string and the value is a string
	messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: a timestamp
	1: (class) a string
	2: (message) a string

	arguments has a value which is a string
type is a string
timestamp is a string

</pre>

=end html

=begin text

$input is a flux_balance_analysis_params
$output is a function_output
flux_balance_analysis_params is a reference to a hash where the following keys are defined:
	model has a value which is a ref
	output_loc has a value which is a ref
	media has a value which is a ref
	fva has a value which is a bool
	simulateko has a value which is a bool
	minimizeflux has a value which is a bool
	findminmedia has a value which is a bool
	allreversible has a value which is a bool
	thermo_const_type has a value which is a thermotype
	media_supplements has a value which is a reference to a list where each element is a string
	geneko has a value which is a reference to a list where each element is a string
	rxnko has a value which is a reference to a list where each element is a string
	output_id has a value which is a string
	maxflux has a value which is a float
	maxuptake has a value which is a float
	minuptake has a value which is a float
	primary_objective_fraction has a value which is a float
	uptakelim has a value which is a reference to a hash where the key is an atomtype and the value is a float
	custom_bounds has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: (type) a vartype
	1: (id) a string
	2: (min) a float
	3: (max) a float

	objective has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (type) a vartype
	1: (id) a string
	2: (coefficient) a float

	custom_constraints has a value which is a reference to a list where each element is a constraint
ref is a string
bool is an int
thermotype is a string
atomtype is a string
vartype is a string
constraint is a reference to a hash where the following keys are defined:
	equality has a value which is a sign
	rhs has a value which is a float
	terms has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (type) a vartype
	1: (id) a string
	2: (coefficient) a float

sign is a string
function_output is a reference to a hash where the following keys are defined:
	path has a value which is a ref
	typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
	output_files has a value which is a reference to a hash where the key is a string and the value is a string
	messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: a timestamp
	1: (class) a string
	2: (message) a string

	arguments has a value which is a string
type is a string
timestamp is a string


=end text



=item Description

Run flux balance analysis on a single model

=back

=cut

sub flux_balance_analysis
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to flux_balance_analysis:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'flux_balance_analysis');
    }

    my $ctx = $Bio::ModelSEED::ProbModelSEED::Server::CallContext;
    my($output);
    #BEGIN flux_balance_analysis
    $output = $self->initialize_call($input);
    $input = $self->_validateargs($input,["output_loc","model"],{
		media => undef,
		fva => 0,
		simulateko => 0,
		minimizeflux => 0,
		findminmedia => 0,
		bool allreversible => 0,
		thermo_const_type => "NO_THERMO"
		media_supplements => [],
		geneko => [],
		rxnko => [],
		output_id;
		maxflux => 1000,
		maxuptake => 0,
		minuptake => -1000,
		primary_objective_fraction => 0.1,
		uptakelim => {},
		custom_bounds => [],
		objective => [],
		custom_constraints => []
	});
    
    
    
    $self->_setContext($ctx,$input);
    $input = $self->_validateargs($input,["model","workspace"],{
		expression_threshold_type => "AbsoluteThreshold",
		low_expression_theshold => 0.5,
		low_expression_penalty_factor => 1,
		high_expression_theshold => 0.5,
		high_expression_penalty_factor => 1,
		alpha => 0.5,
		omega => 0,
		scalefluxes => 0,
		formulation => undef,
		fva => 0,
		simulateko => 0,
		minimizeflux => 0,
		findminmedia => 0,
		notes => "",
		model_workspace => $input->{workspace},
		fba => undef,
		custom_bounds => undef,
		biomass => undef,
		expsample => undef,
		expsamplews => $input->{workspace},
		booleanexp => 0,
		activation_penalty => 0.1,
		solver => undef
	});
	my $model = $self->_get_msobject("FBAModel",$input->{model_workspace},$input->{model});
	if (!defined($input->{fba})) {
		$input->{fba} = $self->_get_new_id($input->{model}.".fba.");
	}
	$input->{formulation} = $self->_setDefaultFBAFormulation($input->{formulation});
	#Creating FBAFormulation Object
	my $fba = $self->_buildFBAObject($input->{formulation},$model,$input->{workspace},$input->{fba});
	if ($input->{booleanexp}) {
		if (defined($input->{expsample})) {
			$input->{expsample} = $self->_get_msobject("ExpressionSample",$input->{expsamplews},$input->{expsample});
		}
		if (!defined($input->{expsample})) {
			$self->_error("Cannot run boolean expression FBA without providing expression data!");	
		}
		$fba->PrepareForGapfilling({
			add_external_rxns => 0,
			activate_all_model_reactions => 0,
			make_model_rxns_reversible => 0,
			expsample => $input->{expsample},
			expression_threshold_type => $input->{expression_threshold_type},
			low_expression_theshold => $input->{low_expression_theshold},
			low_expression_penalty_factor => $input->{low_expression_penalty_factor},
			high_expression_theshold => $input->{high_expression_theshold},
			high_expression_penalty_factor => $input->{high_expression_penalty_factor},
			alpha => $input->{alpha},
			omega => $input->{omega},
			scalefluxes => 0,
		});
	}
	$fba->fva($input->{fva});
	$fba->comboDeletions($input->{simulateko});
	$fba->fluxMinimization($input->{minimizeflux});
	$fba->findMinimalMedia($input->{findminmedia});
	if (defined($input->{solver})) {
	   	$fba->parameters()->{MFASolver} = uc($input->{solver});
	}
	if (defined($input->{biomass}) && defined($fba->biomassflux_objterms()->{bio1})) {
		my $bio = $model->searchForBiomass($input->{biomass});
		if (defined($bio)) {
			delete $fba->biomassflux_objterms()->{bio1};
			$fba->biomassflux_objterms()->{$bio->id()} = 1;
		} else {
			my $rxn = $model->searchForReaction($input->{biomass});
			if (defined($rxn)) {
				delete $fba->biomassflux_objterms()->{bio1};
				$fba->reactionflux_objterms()->{$rxn->id()} = 1;
			} else {
				my $cpd = $model->searchForCompound($input->{biomass});
				if (defined($cpd)) {
					delete $fba->biomassflux_objterms()->{bio1};
					$fba->compoundflux_objterms()->{$cpd->id()} = 1;
				}
			}
		}
	}
	if (defined($input->{custom_bounds})) {
		for (my $i=0; $i < @{$input->{custom_bounds}}; $i++) {
			my $array = [split(/[\<;]/,$input->{custom_bounds}->[$i])];
			my $rxn = $model->searchForReaction($array->[1]);
			if (defined($rxn)) {
				$fba->add("FBAReactionBounds",{
					modelreaction_ref => $rxn->_reference(),
					variableType => "flux",
					upperBound => $array->[2]+0,
					lowerBound => $array->[0]+0
				});
			} else {
				my $cpd = $model->searchForCompound($array->[1]);
				if (defined($cpd)) {
					$fba->add("FBACompoundBounds",{
						modelcompound_ref => $cpd->_reference(),
						variableType => "drainflux",
						upperBound => $array->[2]+0,
						lowerBound => $array->[0]+0
					});
				}
			}
		}
	}
	if (defined($input->{formulation}->{eflux_sample}) && defined($input->{formulation}->{eflux_workspace})) {
		my $scores = $self->_compute_eflux_scores($model,$input->{formulation}->{eflux_series}, $input->{formulation}->{eflux_sample}, $input->{formulation}->{eflux_workspace});
		$self->_add_eflux_bounds($fba, $model, $scores, $input->{formulation}->{eflux_sample});
	}
    #Running FBA
    my $objective;
    eval {
		local $SIG{ALRM} = sub { die "FBA timed out! Model likely contains numerical instability!" };
		alarm 3600;
		$objective = $fba->runFBA();
		alarm 0;
	};
	if ($@) {
		$self->_error($@." See ".$fba->jobnode());
    }
    if (!defined($objective)) {
    	$self->_error("FBA failed with no solution returned! See ".$fba->jobnode());
    }
	$fbaMeta = 
    $fbaMeta->[10]->{Media} = $input->{formulation}->{media_workspace}."/".$input->{formulation}->{media};
    $fbaMeta->[10]->{Objective} = $objective;

    
    
    
    my $model = $self->get_ms_object($input->{model},"model");
	my $media = $self->get_ms_object($input->{media},"media");
	if (!defined($output->{output_id})) {
		$output->{output_id} = $genome->id().".".$media->id().".fba";
	}
	
	
	
    $self->save_msobject($input->{output_loc}."/".$input->{output_id}.".fba",$fba,"fba");
    #END flux_balance_analysis
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to flux_balance_analysis:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'flux_balance_analysis');
    }
    return($output);
}




=head2 gapfill_model

  $output = $obj->gapfill_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a gapfill_model_params
$output is a function_output
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a ref
	output_loc has a value which is a ref
	media has a value which is a ref
	probanno has a value which is a ref
	source_model has a value which is a ref
	comprehensive has a value which is a bool
	allreversible has a value which is a bool
	thermo_const_type has a value which is a thermotype
	media_supplements has a value which is a reference to a list where each element is a string
	geneko has a value which is a reference to a list where each element is a string
	rxnko has a value which is a reference to a list where each element is a string
	output_id has a value which is a string
	maxflux has a value which is a float
	maxuptake has a value which is a float
	minuptake has a value which is a float
	min_objective_value has a value which is a float
	max_objective_fraction has a value which is a float
	uptakelim has a value which is a reference to a hash where the key is an atomtype and the value is a float
	custom_bounds has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: (type) a vartype
	1: (id) a string
	2: (min) a float
	3: (max) a float

	objective has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (type) a vartype
	1: (id) a string
	2: (coefficient) a float

	custom_constraints has a value which is a reference to a list where each element is a constraint
	custom_penalties has a value which is a reference to a hash where the key is a penaltytype and the value is a float
ref is a string
bool is an int
thermotype is a string
atomtype is a string
vartype is a string
constraint is a reference to a hash where the following keys are defined:
	equality has a value which is a sign
	rhs has a value which is a float
	terms has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (type) a vartype
	1: (id) a string
	2: (coefficient) a float

sign is a string
penaltytype is a string
function_output is a reference to a hash where the following keys are defined:
	path has a value which is a ref
	typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
	output_files has a value which is a reference to a hash where the key is a string and the value is a string
	messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: a timestamp
	1: (class) a string
	2: (message) a string

	arguments has a value which is a string
type is a string
timestamp is a string

</pre>

=end html

=begin text

$input is a gapfill_model_params
$output is a function_output
gapfill_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a ref
	output_loc has a value which is a ref
	media has a value which is a ref
	probanno has a value which is a ref
	source_model has a value which is a ref
	comprehensive has a value which is a bool
	allreversible has a value which is a bool
	thermo_const_type has a value which is a thermotype
	media_supplements has a value which is a reference to a list where each element is a string
	geneko has a value which is a reference to a list where each element is a string
	rxnko has a value which is a reference to a list where each element is a string
	output_id has a value which is a string
	maxflux has a value which is a float
	maxuptake has a value which is a float
	minuptake has a value which is a float
	min_objective_value has a value which is a float
	max_objective_fraction has a value which is a float
	uptakelim has a value which is a reference to a hash where the key is an atomtype and the value is a float
	custom_bounds has a value which is a reference to a list where each element is a reference to a list containing 4 items:
	0: (type) a vartype
	1: (id) a string
	2: (min) a float
	3: (max) a float

	objective has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (type) a vartype
	1: (id) a string
	2: (coefficient) a float

	custom_constraints has a value which is a reference to a list where each element is a constraint
	custom_penalties has a value which is a reference to a hash where the key is a penaltytype and the value is a float
ref is a string
bool is an int
thermotype is a string
atomtype is a string
vartype is a string
constraint is a reference to a hash where the following keys are defined:
	equality has a value which is a sign
	rhs has a value which is a float
	terms has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (type) a vartype
	1: (id) a string
	2: (coefficient) a float

sign is a string
penaltytype is a string
function_output is a reference to a hash where the following keys are defined:
	path has a value which is a ref
	typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
	output_files has a value which is a reference to a hash where the key is a string and the value is a string
	messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: a timestamp
	1: (class) a string
	2: (message) a string

	arguments has a value which is a string
type is a string
timestamp is a string


=end text



=item Description

Gapfills a model in a single condition

=back

=cut

sub gapfill_model
{
    my $self = shift;
    my($input) = @_;

    my @_bad_arguments;
    (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument \"input\" (value was \"$input\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_model');
    }

    my $ctx = $Bio::ModelSEED::ProbModelSEED::Server::CallContext;
    my($output);
    #BEGIN gapfill_model
    $output = $self->initialize_call($input);
    $input = $self->_validateargs($input,["output_loc","model"],{
		media => undef,
		probanno => undef,
		source_model => undef,
		comprehensive => 0,
		allreversible => 0,
		thermo_const_type => "NO_THERMO",
		media_supplements => [],
		geneko => [],
		rxnko => [],
		output_id => undef,
		maxflux => 1000,
		maxuptake => 0,
		minuptake => -1000,
		min_objective_value => 0.00001,
		max_objective_fraction => 0.1,
		uptakelim => {},
		custom_bounds => [],
		objective => [],
		custom_constraints => [],
		custom_penalties => {}
	});
	my $model = $self->get_ms_object($input->{model},"model");
	my $media = $self->get_ms_object($input->{media},"media");
	$model = $self->_gapfill_model($model,{
		media => $input->{media}
	});
	my $gapfilled_reactions = [];
	#Saving gapfilled reaction list to database
	$self->save_ms_object($input->{output_loc}."/".$input->{output_id}."/".$input->{output_id}."_gapfilled_reactions.txt",join("\n",@{$gapfilled_reactions}),"txt");
	my $fba = $model->runfba({
		
	});
	my $essential_genes = [];
	#Saving essential gene list to database
	$self->save_ms_object($input->{output_loc}."/".$input->{output_id}."/".$input->{output_id}."_essential_genes.txt",join("\n",@{$essential_genes}),"txt");
	$self->_save_model($model,$input->{output_loc}."/".$input->{output_id}."/".$input->{output_id});
    #END gapfill_model
    my @_bad_returns;
    (ref($output) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"output\" (value was \"$output\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'gapfill_model');
    }
    return($output);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 bool

=over 4



=item Description

********************************************************************************
    Universal simple type definitions
   	********************************************************************************


=item Definition

=begin html

<pre>
an int
</pre>

=end html

=begin text

an int

=end text

=back



=head2 ref

=over 4



=item Description

Reference to location in PATRIC workspace (e.g. /home/chenry/models/MyModel)


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 timestamp

=over 4



=item Description

Standard perl timestamp (e.g. 2015-03-21-02:14:53)


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 vartype

=over 4



=item Description

An enum of the various variable types in FBA [flux/drainflux/biomassflux]


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 thermotype

=over 4



=item Description

An enum of the various types of thermodynamic variables in FBA [NO_THERMO/SIMPLE_THERMO/THERMO_NO_ERROR/THERMO_MIN_ERROR]


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 sign

=over 4



=item Description

An enum of the various types of signs in FBA constraints [</=/>]


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 penaltytype

=over 4



=item Description

An enum of the various penalty types in FBA [NO_STRUCTURE/INFEASIBLE_DIRECTION/NON_KEGG/DELTAG_MULTIPLIER... incomplete list]


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 mediaformat

=over 4



=item Description

An enum of file formats for input media file [TSV]


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 type

=over 4



=item Description

An enum of accepted workspace types [see workspace repo for options]


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 atomtype

=over 4



=item Description

An enum of atom types in potential uptake limits [C/N/P/O/S]


=item Definition

=begin html

<pre>
a string
</pre>

=end html

=begin text

a string

=end text

=back



=head2 constraint

=over 4



=item Description

********************************************************************************
    Complex data structures to support functions
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
equality has a value which is a sign
rhs has a value which is a float
terms has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (type) a vartype
1: (id) a string
2: (coefficient) a float


</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
equality has a value which is a sign
rhs has a value which is a float
terms has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (type) a vartype
1: (id) a string
2: (coefficient) a float



=end text

=back



=head2 function_output

=over 4



=item Description

This is a standard data-structure returned as output for all functions 
ref path - reference to location where output folder is stored
mapping<type,list<string>> typed_objects_generated - list of typed objects generated by function, organized by type
list<tuple<timestamp,string class,string message>> messages - messages generated by function to report on operations


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
path has a value which is a ref
typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
output_files has a value which is a reference to a hash where the key is a string and the value is a string
messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: a timestamp
1: (class) a string
2: (message) a string

arguments has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
path has a value which is a ref
typed_objects_generated has a value which is a reference to a hash where the key is a type and the value is a reference to a list where each element is a string
output_files has a value which is a reference to a hash where the key is a string and the value is a string
messages has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: a timestamp
1: (class) a string
2: (message) a string

arguments has a value which is a string


=end text

=back



=head2 import_media_params

=over 4



=item Description

********************************************************************************
    Functions for data transformation and integration
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
mediafile has a value which is a ref
output_loc has a value which is a ref
ouput_id has a value which is a string
format has a value which is a mediaformat

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
mediafile has a value which is a ref
output_loc has a value which is a ref
ouput_id has a value which is a string
format has a value which is a mediaformat


=end text

=back



=head2 reconstruct_fbamodel_params

=over 4



=item Description

********************************************************************************
    Functions for model reconstruction and analysis
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a ref
output_loc has a value which is a ref
template_model has a value which is a ref
ouput_id has a value which is a string
coremodel has a value which is a bool
fulldb has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a ref
output_loc has a value which is a ref
template_model has a value which is a ref
ouput_id has a value which is a string
coremodel has a value which is a bool
fulldb has a value which is a bool


=end text

=back



=head2 flux_balance_analysis_params

=over 4



=item Description

Input parameters for the "flux_balance_analysis" function.

        Required inputs:
        ref model - reference to model on which FBA should be run
        
        Optional inputs:
        ref output_loc - location where output should be printed
        ref media - reference to media for FBA study
        bool fva;
        bool simulateko;
        bool minimizeflux;
        bool findminmedia;
        bool allreversible;
        thermotype thermo_const_type;
        list<string> media_supplements;
        list<string> geneko;
        list<string> rxnko;
        string output_id;
        float maxflux;
        float maxuptake;
        float minuptake;
        float primary_objective_fraction;
        mapping<atomtype,float> uptakelim;
        list<tuple<vartype type,string id,float min,float max>> custom_bounds;
        list<tuple<vartype type,string id,float coefficient>> objective;
        list<constraint> custom_constraints;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a ref
output_loc has a value which is a ref
media has a value which is a ref
fva has a value which is a bool
simulateko has a value which is a bool
minimizeflux has a value which is a bool
findminmedia has a value which is a bool
allreversible has a value which is a bool
thermo_const_type has a value which is a thermotype
media_supplements has a value which is a reference to a list where each element is a string
geneko has a value which is a reference to a list where each element is a string
rxnko has a value which is a reference to a list where each element is a string
output_id has a value which is a string
maxflux has a value which is a float
maxuptake has a value which is a float
minuptake has a value which is a float
primary_objective_fraction has a value which is a float
uptakelim has a value which is a reference to a hash where the key is an atomtype and the value is a float
custom_bounds has a value which is a reference to a list where each element is a reference to a list containing 4 items:
0: (type) a vartype
1: (id) a string
2: (min) a float
3: (max) a float

objective has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (type) a vartype
1: (id) a string
2: (coefficient) a float

custom_constraints has a value which is a reference to a list where each element is a constraint

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a ref
output_loc has a value which is a ref
media has a value which is a ref
fva has a value which is a bool
simulateko has a value which is a bool
minimizeflux has a value which is a bool
findminmedia has a value which is a bool
allreversible has a value which is a bool
thermo_const_type has a value which is a thermotype
media_supplements has a value which is a reference to a list where each element is a string
geneko has a value which is a reference to a list where each element is a string
rxnko has a value which is a reference to a list where each element is a string
output_id has a value which is a string
maxflux has a value which is a float
maxuptake has a value which is a float
minuptake has a value which is a float
primary_objective_fraction has a value which is a float
uptakelim has a value which is a reference to a hash where the key is an atomtype and the value is a float
custom_bounds has a value which is a reference to a list where each element is a reference to a list containing 4 items:
0: (type) a vartype
1: (id) a string
2: (min) a float
3: (max) a float

objective has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (type) a vartype
1: (id) a string
2: (coefficient) a float

custom_constraints has a value which is a reference to a list where each element is a constraint


=end text

=back



=head2 gapfill_model_params

=over 4



=item Description

Input parameters for the "gapfill_model" function.

        Required inputs:
        ref model - reference to model on which gapfilling should be run
        
        Optional inputs:
        ref output_loc - location where output should be printed
        ref media - reference to media for FBA study
        ref probanno - reference to probabilistic annotation for gapfilling
        ref source_model - reference to model with source biochemistry for gapfilling
        bool comprehensive - a boolean indicating 
        bool allreversible;
        thermotype thermo_const_type;
        list<string> media_supplements;
        list<string> geneko;
        list<string> rxnko;
        string output_id;
        float maxflux;
        float maxuptake;
        float minuptake;
        float min_objective_value;
        float max_objective_fraction;
        mapping<atomtype,float> uptakelim;
        list<tuple<vartype type,string id,float min,float max>> custom_bounds;
        list<tuple<vartype type,string id,float coefficient>> objective;
        list<constraint> custom_constraints;
        mapping<penaltytype,float> custom_penalties;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a ref
output_loc has a value which is a ref
media has a value which is a ref
probanno has a value which is a ref
source_model has a value which is a ref
comprehensive has a value which is a bool
allreversible has a value which is a bool
thermo_const_type has a value which is a thermotype
media_supplements has a value which is a reference to a list where each element is a string
geneko has a value which is a reference to a list where each element is a string
rxnko has a value which is a reference to a list where each element is a string
output_id has a value which is a string
maxflux has a value which is a float
maxuptake has a value which is a float
minuptake has a value which is a float
min_objective_value has a value which is a float
max_objective_fraction has a value which is a float
uptakelim has a value which is a reference to a hash where the key is an atomtype and the value is a float
custom_bounds has a value which is a reference to a list where each element is a reference to a list containing 4 items:
0: (type) a vartype
1: (id) a string
2: (min) a float
3: (max) a float

objective has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (type) a vartype
1: (id) a string
2: (coefficient) a float

custom_constraints has a value which is a reference to a list where each element is a constraint
custom_penalties has a value which is a reference to a hash where the key is a penaltytype and the value is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a ref
output_loc has a value which is a ref
media has a value which is a ref
probanno has a value which is a ref
source_model has a value which is a ref
comprehensive has a value which is a bool
allreversible has a value which is a bool
thermo_const_type has a value which is a thermotype
media_supplements has a value which is a reference to a list where each element is a string
geneko has a value which is a reference to a list where each element is a string
rxnko has a value which is a reference to a list where each element is a string
output_id has a value which is a string
maxflux has a value which is a float
maxuptake has a value which is a float
minuptake has a value which is a float
min_objective_value has a value which is a float
max_objective_fraction has a value which is a float
uptakelim has a value which is a reference to a hash where the key is an atomtype and the value is a float
custom_bounds has a value which is a reference to a list where each element is a reference to a list containing 4 items:
0: (type) a vartype
1: (id) a string
2: (min) a float
3: (max) a float

objective has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (type) a vartype
1: (id) a string
2: (coefficient) a float

custom_constraints has a value which is a reference to a list where each element is a constraint
custom_penalties has a value which is a reference to a hash where the key is a penaltytype and the value is a float


=end text

=back



=cut

1;
