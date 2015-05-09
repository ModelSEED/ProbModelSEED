package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient;

use JSON::RPC::Client;
use POSIX;
use strict;
use Data::Dumper;
use URI;
use Bio::KBase::Exceptions;
my $get_time = sub { time, 0 };
eval {
    require Time::HiRes;
    $get_time = sub { Time::HiRes::gettimeofday() };
};

use Bio::KBase::AuthToken;

# Client version should match Impl version
# This is a Semantic Version number,
# http://semver.org
our $VERSION = "0.1.0";

=head1 NAME

Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient

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

sub new
{
    my($class, $url, @args) = @_;
    

    my $self = {
	client => Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient::RpcClient->new,
	url => $url,
	headers => [],
    };

    chomp($self->{hostname} = `hostname`);
    $self->{hostname} ||= 'unknown-host';

    #
    # Set up for propagating KBRPC_TAG and KBRPC_METADATA environment variables through
    # to invoked services. If these values are not set, we create a new tag
    # and a metadata field with basic information about the invoking script.
    #
    if ($ENV{KBRPC_TAG})
    {
	$self->{kbrpc_tag} = $ENV{KBRPC_TAG};
    }
    else
    {
	my ($t, $us) = &$get_time();
	$us = sprintf("%06d", $us);
	my $ts = strftime("%Y-%m-%dT%H:%M:%S.${us}Z", gmtime $t);
	$self->{kbrpc_tag} = "C:$0:$self->{hostname}:$$:$ts";
    }
    push(@{$self->{headers}}, 'Kbrpc-Tag', $self->{kbrpc_tag});

    if ($ENV{KBRPC_METADATA})
    {
	$self->{kbrpc_metadata} = $ENV{KBRPC_METADATA};
	push(@{$self->{headers}}, 'Kbrpc-Metadata', $self->{kbrpc_metadata});
    }

    if ($ENV{KBRPC_ERROR_DEST})
    {
	$self->{kbrpc_error_dest} = $ENV{KBRPC_ERROR_DEST};
	push(@{$self->{headers}}, 'Kbrpc-Errordest', $self->{kbrpc_error_dest});
    }

    #
    # This module requires authentication.
    #
    # We create an auth token, passing through the arguments that we were (hopefully) given.

    {
	my $token = Bio::KBase::AuthToken->new(@args);
	
	if (!$token->error_message)
	{
	    $self->{token} = $token->token;
	    $self->{client}->{token} = $token->token;
	}
        else
        {
	    #
	    # All methods in this module require authentication. In this case, if we
	    # don't have a token, we can't continue.
	    #
	    die "Authentication failed: " . $token->error_message;
	}
    }

    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    bless $self, $class;
    #    $self->_validate_version();
    return $self;
}




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
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function import_media (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to import_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'import_media');
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.import_media",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'import_media',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method import_media",
					    status_line => $self->{client}->status_line,
					    method_name => 'import_media',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function reconstruct_fbamodel (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to reconstruct_fbamodel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'reconstruct_fbamodel');
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.reconstruct_fbamodel",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'reconstruct_fbamodel',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method reconstruct_fbamodel",
					    status_line => $self->{client}->status_line,
					    method_name => 'reconstruct_fbamodel',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function flux_balance_analysis (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to flux_balance_analysis:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'flux_balance_analysis');
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.flux_balance_analysis",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'flux_balance_analysis',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method flux_balance_analysis",
					    status_line => $self->{client}->status_line,
					    method_name => 'flux_balance_analysis',
				       );
    }
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
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error =>
							       "Invalid argument count for function gapfill_model (received $n, expecting 1)");
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to gapfill_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
								   method_name => 'gapfill_model');
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.gapfill_model",
	params => \@args,
    });
    if ($result) {
	if ($result->is_error) {
	    Bio::KBase::Exceptions::JSONRPC->throw(error => $result->error_message,
					       code => $result->content->{error}->{code},
					       method_name => 'gapfill_model',
					       data => $result->content->{error}->{error} # JSON::RPC::ReturnObject only supports JSONRPC 1.1 or 1.O
					      );
	} else {
	    return wantarray ? @{$result->result} : $result->result->[0];
	}
    } else {
        Bio::KBase::Exceptions::HTTP->throw(error => "Error invoking method gapfill_model",
					    status_line => $self->{client}->status_line,
					    method_name => 'gapfill_model',
				       );
    }
}



sub version {
    my ($self) = @_;
    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
        method => "ProbModelSEED.version",
        params => [],
    });
    if ($result) {
        if ($result->is_error) {
            Bio::KBase::Exceptions::JSONRPC->throw(
                error => $result->error_message,
                code => $result->content->{code},
                method_name => 'gapfill_model',
            );
        } else {
            return wantarray ? @{$result->result} : $result->result->[0];
        }
    } else {
        Bio::KBase::Exceptions::HTTP->throw(
            error => "Error invoking method gapfill_model",
            status_line => $self->{client}->status_line,
            method_name => 'gapfill_model',
        );
    }
}

sub _validate_version {
    my ($self) = @_;
    my $svr_version = $self->version();
    my $client_version = $VERSION;
    my ($cMajor, $cMinor) = split(/\./, $client_version);
    my ($sMajor, $sMinor) = split(/\./, $svr_version);
    if ($sMajor != $cMajor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Major version numbers differ.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor < $cMinor) {
        Bio::KBase::Exceptions::ClientServerIncompatible->throw(
            error => "Client minor version greater than Server minor version.",
            server_version => $svr_version,
            client_version => $client_version
        );
    }
    if ($sMinor > $cMinor) {
        warn "New client version available for Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient\n";
    }
    if ($sMajor == 0) {
        warn "Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient version is $svr_version. API subject to change.\n";
    }
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

package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient::RpcClient;
use base 'JSON::RPC::Client';
use POSIX;
use strict;

#
# Override JSON::RPC::Client::call because it doesn't handle error returns properly.
#

sub call {
    my ($self, $uri, $headers, $obj) = @_;
    my $result;


    {
	if ($uri =~ /\?/) {
	    $result = $self->_get($uri);
	}
	else {
	    Carp::croak "not hashref." unless (ref $obj eq 'HASH');
	    $result = $self->_post($uri, $headers, $obj);
	}

    }

    my $service = $obj->{method} =~ /^system\./ if ( $obj );

    $self->status_line($result->status_line);

    if ($result->is_success) {

        return unless($result->content); # notification?

        if ($service) {
            return JSON::RPC::ServiceObject->new($result, $self->json);
        }

        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    elsif ($result->content_type eq 'application/json')
    {
        return JSON::RPC::ReturnObject->new($result, $self->json);
    }
    else {
        return;
    }
}


sub _post {
    my ($self, $uri, $headers, $obj) = @_;
    my $json = $self->json;

    $obj->{version} ||= $self->{version} || '1.1';

    if ($obj->{version} eq '1.0') {
        delete $obj->{version};
        if (exists $obj->{id}) {
            $self->id($obj->{id}) if ($obj->{id}); # if undef, it is notification.
        }
        else {
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Client'));
        }
    }
    else {
        # $obj->{id} = $self->id if (defined $self->id);
	# Assign a random number to the id if one hasn't been set
	$obj->{id} = (defined $self->id) ? $self->id : substr(rand(),2);
    }

    my $content = $json->encode($obj);

    $self->ua->post(
        $uri,
        Content_Type   => $self->{content_type},
        Content        => $content,
        Accept         => 'application/json',
	@$headers,
	($self->{token} ? (Authorization => $self->{token}) : ()),
    );
}



1;
