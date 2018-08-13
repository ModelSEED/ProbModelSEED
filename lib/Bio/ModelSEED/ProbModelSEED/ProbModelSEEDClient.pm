package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient;

use POSIX;
use strict;
use Data::Dumper;
use URI;

my $get_time = sub { time, 0 };
eval {
    require Time::HiRes;
    $get_time = sub { Time::HiRes::gettimeofday() };
};

use P3AuthToken;


=head1 NAME

Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient

=head1 DESCRIPTION


=head1 ProbModelSEED


=cut


sub new
{
    my($class, $url, @args) = @_;
    
    if (!defined($url))
    {
	$url = 'http://p3.theseed.org/services/ProbModelSEED';
    }

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
	my $token = P3AuthToken->new(@args);
	
	if (my $token_str = $token->token())
	{
	    $self->{token} = $token_str;
	    $self->{client}->{token} = $token_str;
	}
        else
        {
	    #
	    # All methods in this module require authentication. In this case, if we
	    # don't have a token, we can't continue.
	    #
	    die "Authentication failed\n";
	}
    }

    my $ua = $self->{client}->ua;	 
    my $timeout = $ENV{CDMI_TIMEOUT} || (30 * 60);	 
    $ua->timeout($timeout);
    $ua->agent("Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient UserAgent");
    bless $self, $class;
    return $self;
}




=head2 list_gapfill_solutions

  $output = $obj->list_gapfill_solutions($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a list_gapfill_solutions_params
$output is a reference to a list where each element is a gapfill_data
list_gapfill_solutions_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
gapfill_data is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a gapfill_id
	ref has a value which is a reference
	media_ref has a value which is a reference
	integrated has a value which is a bool
	integrated_solution has a value which is an int
	solution_reactions has a value which is a reference to a list where each element is a reference to a list where each element is a gapfill_reaction
Timestamp is a string
gapfill_id is a string
bool is an int
gapfill_reaction is a reference to a hash where the following keys are defined:
	reaction has a value which is a reference
	direction has a value which is a reaction_direction
	compartment has a value which is a string
reaction_direction is a string

</pre>

=end html

=begin text

$input is a list_gapfill_solutions_params
$output is a reference to a list where each element is a gapfill_data
list_gapfill_solutions_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
gapfill_data is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a gapfill_id
	ref has a value which is a reference
	media_ref has a value which is a reference
	integrated has a value which is a bool
	integrated_solution has a value which is an int
	solution_reactions has a value which is a reference to a list where each element is a reference to a list where each element is a gapfill_reaction
Timestamp is a string
gapfill_id is a string
bool is an int
gapfill_reaction is a reference to a hash where the following keys are defined:
	reaction has a value which is a reference
	direction has a value which is a reaction_direction
	compartment has a value which is a string
reaction_direction is a string


=end text

=item Description



=back

=cut

sub list_gapfill_solutions
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function list_gapfill_solutions (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to list_gapfill_solutions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.list_gapfill_solutions",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking list_gapfill_solutions:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method list_gapfill_solutions: " .  $self->{client}->status_line;
    }
}



=head2 manage_gapfill_solutions

  $output = $obj->manage_gapfill_solutions($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a manage_gapfill_solutions_params
$output is a reference to a hash where the key is a gapfill_id and the value is a gapfill_data
manage_gapfill_solutions_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	commands has a value which is a reference to a hash where the key is a gapfill_id and the value is a gapfill_command
	selected_solutions has a value which is a reference to a hash where the key is a gapfill_id and the value is an int
reference is a string
gapfill_id is a string
gapfill_command is a string
gapfill_data is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a gapfill_id
	ref has a value which is a reference
	media_ref has a value which is a reference
	integrated has a value which is a bool
	integrated_solution has a value which is an int
	solution_reactions has a value which is a reference to a list where each element is a reference to a list where each element is a gapfill_reaction
Timestamp is a string
bool is an int
gapfill_reaction is a reference to a hash where the following keys are defined:
	reaction has a value which is a reference
	direction has a value which is a reaction_direction
	compartment has a value which is a string
reaction_direction is a string

</pre>

=end html

=begin text

$input is a manage_gapfill_solutions_params
$output is a reference to a hash where the key is a gapfill_id and the value is a gapfill_data
manage_gapfill_solutions_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	commands has a value which is a reference to a hash where the key is a gapfill_id and the value is a gapfill_command
	selected_solutions has a value which is a reference to a hash where the key is a gapfill_id and the value is an int
reference is a string
gapfill_id is a string
gapfill_command is a string
gapfill_data is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a gapfill_id
	ref has a value which is a reference
	media_ref has a value which is a reference
	integrated has a value which is a bool
	integrated_solution has a value which is an int
	solution_reactions has a value which is a reference to a list where each element is a reference to a list where each element is a gapfill_reaction
Timestamp is a string
bool is an int
gapfill_reaction is a reference to a hash where the following keys are defined:
	reaction has a value which is a reference
	direction has a value which is a reaction_direction
	compartment has a value which is a string
reaction_direction is a string


=end text

=item Description



=back

=cut

sub manage_gapfill_solutions
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function manage_gapfill_solutions (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to manage_gapfill_solutions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.manage_gapfill_solutions",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking manage_gapfill_solutions:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method manage_gapfill_solutions: " .  $self->{client}->status_line;
    }
}



=head2 list_fba_studies

  $output = $obj->list_fba_studies($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a list_fba_studies_params
$output is a reference to a list where each element is a fba_data
list_fba_studies_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
fba_data is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a fba_id
	ref has a value which is a reference
	objective has a value which is a float
	media_ref has a value which is a reference
	objective_function has a value which is a string
Timestamp is a string
fba_id is a string

</pre>

=end html

=begin text

$input is a list_fba_studies_params
$output is a reference to a list where each element is a fba_data
list_fba_studies_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
fba_data is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a fba_id
	ref has a value which is a reference
	objective has a value which is a float
	media_ref has a value which is a reference
	objective_function has a value which is a string
Timestamp is a string
fba_id is a string


=end text

=item Description



=back

=cut

sub list_fba_studies
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function list_fba_studies (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to list_fba_studies:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.list_fba_studies",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking list_fba_studies:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method list_fba_studies: " .  $self->{client}->status_line;
    }
}



=head2 delete_fba_studies

  $output = $obj->delete_fba_studies($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a delete_fba_studies_params
$output is a reference to a hash where the key is a fba_id and the value is a fba_data
delete_fba_studies_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	commands has a value which is a reference to a hash where the key is a gapfill_id and the value is a gapfill_command
reference is a string
gapfill_id is a string
gapfill_command is a string
fba_id is a string
fba_data is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a fba_id
	ref has a value which is a reference
	objective has a value which is a float
	media_ref has a value which is a reference
	objective_function has a value which is a string
Timestamp is a string

</pre>

=end html

=begin text

$input is a delete_fba_studies_params
$output is a reference to a hash where the key is a fba_id and the value is a fba_data
delete_fba_studies_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	commands has a value which is a reference to a hash where the key is a gapfill_id and the value is a gapfill_command
reference is a string
gapfill_id is a string
gapfill_command is a string
fba_id is a string
fba_data is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a fba_id
	ref has a value which is a reference
	objective has a value which is a float
	media_ref has a value which is a reference
	objective_function has a value which is a string
Timestamp is a string


=end text

=item Description



=back

=cut

sub delete_fba_studies
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function delete_fba_studies (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to delete_fba_studies:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.delete_fba_studies",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking delete_fba_studies:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method delete_fba_studies: " .  $self->{client}->status_line;
    }
}



=head2 export_model

  $output = $obj->export_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an export_model_params
$output is a string
export_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	format has a value which is a string
	to_shock has a value which is a bool
reference is a string
bool is an int

</pre>

=end html

=begin text

$input is an export_model_params
$output is a string
export_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	format has a value which is a string
	to_shock has a value which is a bool
reference is a string
bool is an int


=end text

=item Description



=back

=cut

sub export_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function export_model (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.export_model",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking export_model:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method export_model: " .  $self->{client}->status_line;
    }
}



=head2 export_media

  $output = $obj->export_media($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an export_media_params
$output is a string
export_media_params is a reference to a hash where the following keys are defined:
	media has a value which is a reference
	to_shock has a value which is a bool
reference is a string
bool is an int

</pre>

=end html

=begin text

$input is an export_media_params
$output is a string
export_media_params is a reference to a hash where the following keys are defined:
	media has a value which is a reference
	to_shock has a value which is a bool
reference is a string
bool is an int


=end text

=item Description



=back

=cut

sub export_media
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function export_media (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to export_media:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.export_media",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking export_media:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method export_media: " .  $self->{client}->status_line;
    }
}



=head2 get_model

  $output = $obj->get_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_model_params
$output is a model_data
get_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
model_data is a reference to a hash where the following keys are defined:
	ref has a value which is a reference
	reactions has a value which is a reference to a list where each element is a model_reaction
	compounds has a value which is a reference to a list where each element is a model_compound
	genes has a value which is a reference to a list where each element is a model_gene
	compartments has a value which is a reference to a list where each element is a model_compartment
	biomasses has a value which is a reference to a list where each element is a model_biomass
model_reaction is a reference to a hash where the following keys are defined:
	id has a value which is a reaction_id
	name has a value which is a string
	stoichiometry has a value which is a reference to a list where each element is a reference to a list containing 5 items:
	0: (coefficient) a float
	1: (id) a compound_id
	2: (compartment) a compartment_id
	3: (compartment_index) an int
	4: (name) a string

	direction has a value which is a string
	gpr has a value which is a string
	genes has a value which is a reference to a list where each element is a gene_id
reaction_id is a string
compound_id is a string
compartment_id is a string
gene_id is a string
model_compound is a reference to a hash where the following keys are defined:
	id has a value which is a compound_id
	name has a value which is a string
	formula has a value which is a string
	charge has a value which is a float
model_gene is a reference to a hash where the following keys are defined:
	id has a value which is a gene_id
	reactions has a value which is a reference to a list where each element is a reaction_id
model_compartment is a reference to a hash where the following keys are defined:
	id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
model_biomass is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	compounds has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (compound) a compound_id
	1: (coefficient) a float
	2: (compartment) a compartment_id

biomass_id is a string

</pre>

=end html

=begin text

$input is a get_model_params
$output is a model_data
get_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
model_data is a reference to a hash where the following keys are defined:
	ref has a value which is a reference
	reactions has a value which is a reference to a list where each element is a model_reaction
	compounds has a value which is a reference to a list where each element is a model_compound
	genes has a value which is a reference to a list where each element is a model_gene
	compartments has a value which is a reference to a list where each element is a model_compartment
	biomasses has a value which is a reference to a list where each element is a model_biomass
model_reaction is a reference to a hash where the following keys are defined:
	id has a value which is a reaction_id
	name has a value which is a string
	stoichiometry has a value which is a reference to a list where each element is a reference to a list containing 5 items:
	0: (coefficient) a float
	1: (id) a compound_id
	2: (compartment) a compartment_id
	3: (compartment_index) an int
	4: (name) a string

	direction has a value which is a string
	gpr has a value which is a string
	genes has a value which is a reference to a list where each element is a gene_id
reaction_id is a string
compound_id is a string
compartment_id is a string
gene_id is a string
model_compound is a reference to a hash where the following keys are defined:
	id has a value which is a compound_id
	name has a value which is a string
	formula has a value which is a string
	charge has a value which is a float
model_gene is a reference to a hash where the following keys are defined:
	id has a value which is a gene_id
	reactions has a value which is a reference to a list where each element is a reaction_id
model_compartment is a reference to a hash where the following keys are defined:
	id has a value which is a compartment_id
	name has a value which is a string
	pH has a value which is a float
	potential has a value which is a float
model_biomass is a reference to a hash where the following keys are defined:
	id has a value which is a biomass_id
	compounds has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (compound) a compound_id
	1: (coefficient) a float
	2: (compartment) a compartment_id

biomass_id is a string


=end text

=item Description



=back

=cut

sub get_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function get_model (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.get_model",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking get_model:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method get_model: " .  $self->{client}->status_line;
    }
}



=head2 delete_model

  $output = $obj->delete_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a delete_model_params
$output is an ObjectMeta
delete_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectName
	1: an ObjectType
	2: a FullObjectPath
	3: (creation_time) a Timestamp
	4: an ObjectID
	5: (object_owner) a Username
	6: an ObjectSize
	7: a UserMetadata
	8: an AutoMetadata
	9: (user_permission) a WorkspacePerm
	10: (global_permission) a WorkspacePerm
	11: (shockurl) a string
ObjectName is a string
ObjectType is a string
FullObjectPath is a string
Timestamp is a string
ObjectID is a string
Username is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string
WorkspacePerm is a string

</pre>

=end html

=begin text

$input is a delete_model_params
$output is an ObjectMeta
delete_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectName
	1: an ObjectType
	2: a FullObjectPath
	3: (creation_time) a Timestamp
	4: an ObjectID
	5: (object_owner) a Username
	6: an ObjectSize
	7: a UserMetadata
	8: an AutoMetadata
	9: (user_permission) a WorkspacePerm
	10: (global_permission) a WorkspacePerm
	11: (shockurl) a string
ObjectName is a string
ObjectType is a string
FullObjectPath is a string
Timestamp is a string
ObjectID is a string
Username is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string
WorkspacePerm is a string


=end text

=item Description



=back

=cut

sub delete_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function delete_model (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to delete_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.delete_model",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking delete_model:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method delete_model: " .  $self->{client}->status_line;
    }
}



=head2 list_models

  $output = $obj->list_models($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a list_models_params
$output is a reference to a list where each element is a ModelStats
list_models_params is a reference to a hash where the following keys are defined:
	path has a value which is a reference
reference is a string
ModelStats is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a string
	source has a value which is a string
	source_id has a value which is a string
	name has a value which is a string
	type has a value which is a string
	ref has a value which is a reference
	genome_ref has a value which is a reference
	template_ref has a value which is a reference
	fba_count has a value which is an int
	integrated_gapfills has a value which is an int
	unintegrated_gapfills has a value which is an int
	gene_associated_reactions has a value which is an int
	gapfilled_reactions has a value which is an int
	num_genes has a value which is an int
	num_compounds has a value which is an int
	num_reactions has a value which is an int
	num_biomasses has a value which is an int
	num_biomass_compounds has a value which is an int
	num_compartments has a value which is an int
Timestamp is a string

</pre>

=end html

=begin text

$input is a list_models_params
$output is a reference to a list where each element is a ModelStats
list_models_params is a reference to a hash where the following keys are defined:
	path has a value which is a reference
reference is a string
ModelStats is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a string
	source has a value which is a string
	source_id has a value which is a string
	name has a value which is a string
	type has a value which is a string
	ref has a value which is a reference
	genome_ref has a value which is a reference
	template_ref has a value which is a reference
	fba_count has a value which is an int
	integrated_gapfills has a value which is an int
	unintegrated_gapfills has a value which is an int
	gene_associated_reactions has a value which is an int
	gapfilled_reactions has a value which is an int
	num_genes has a value which is an int
	num_compounds has a value which is an int
	num_reactions has a value which is an int
	num_biomasses has a value which is an int
	num_biomass_compounds has a value which is an int
	num_compartments has a value which is an int
Timestamp is a string


=end text

=item Description



=back

=cut

sub list_models
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function list_models (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to list_models:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.list_models",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking list_models:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method list_models: " .  $self->{client}->status_line;
    }
}



=head2 copy_model

  $output = $obj->copy_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a copy_model_params
$output is a ModelStats
copy_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	destination has a value which is a reference
	destname has a value which is a string
	copy_genome has a value which is a bool
	to_kbase has a value which is a bool
	workspace_url has a value which is a string
	kbase_username has a value which is a string
	kbase_password has a value which is a string
	plantseed has a value which is a bool
reference is a string
bool is an int
ModelStats is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a string
	source has a value which is a string
	source_id has a value which is a string
	name has a value which is a string
	type has a value which is a string
	ref has a value which is a reference
	genome_ref has a value which is a reference
	template_ref has a value which is a reference
	fba_count has a value which is an int
	integrated_gapfills has a value which is an int
	unintegrated_gapfills has a value which is an int
	gene_associated_reactions has a value which is an int
	gapfilled_reactions has a value which is an int
	num_genes has a value which is an int
	num_compounds has a value which is an int
	num_reactions has a value which is an int
	num_biomasses has a value which is an int
	num_biomass_compounds has a value which is an int
	num_compartments has a value which is an int
Timestamp is a string

</pre>

=end html

=begin text

$input is a copy_model_params
$output is a ModelStats
copy_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	destination has a value which is a reference
	destname has a value which is a string
	copy_genome has a value which is a bool
	to_kbase has a value which is a bool
	workspace_url has a value which is a string
	kbase_username has a value which is a string
	kbase_password has a value which is a string
	plantseed has a value which is a bool
reference is a string
bool is an int
ModelStats is a reference to a hash where the following keys are defined:
	rundate has a value which is a Timestamp
	id has a value which is a string
	source has a value which is a string
	source_id has a value which is a string
	name has a value which is a string
	type has a value which is a string
	ref has a value which is a reference
	genome_ref has a value which is a reference
	template_ref has a value which is a reference
	fba_count has a value which is an int
	integrated_gapfills has a value which is an int
	unintegrated_gapfills has a value which is an int
	gene_associated_reactions has a value which is an int
	gapfilled_reactions has a value which is an int
	num_genes has a value which is an int
	num_compounds has a value which is an int
	num_reactions has a value which is an int
	num_biomasses has a value which is an int
	num_biomass_compounds has a value which is an int
	num_compartments has a value which is an int
Timestamp is a string


=end text

=item Description



=back

=cut

sub copy_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function copy_model (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to copy_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.copy_model",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking copy_model:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method copy_model: " .  $self->{client}->status_line;
    }
}



=head2 copy_genome

  $output = $obj->copy_genome($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a copy_genome_params
$output is an ObjectMeta
copy_genome_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
	destination has a value which is a reference
	destname has a value which is a string
	to_kbase has a value which is a bool
	workspace_url has a value which is a string
	kbase_username has a value which is a string
	kbase_password has a value which is a string
	plantseed has a value which is a bool
reference is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectName
	1: an ObjectType
	2: a FullObjectPath
	3: (creation_time) a Timestamp
	4: an ObjectID
	5: (object_owner) a Username
	6: an ObjectSize
	7: a UserMetadata
	8: an AutoMetadata
	9: (user_permission) a WorkspacePerm
	10: (global_permission) a WorkspacePerm
	11: (shockurl) a string
ObjectName is a string
ObjectType is a string
FullObjectPath is a string
Timestamp is a string
ObjectID is a string
Username is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string
WorkspacePerm is a string

</pre>

=end html

=begin text

$input is a copy_genome_params
$output is an ObjectMeta
copy_genome_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
	destination has a value which is a reference
	destname has a value which is a string
	to_kbase has a value which is a bool
	workspace_url has a value which is a string
	kbase_username has a value which is a string
	kbase_password has a value which is a string
	plantseed has a value which is a bool
reference is a string
bool is an int
ObjectMeta is a reference to a list containing 12 items:
	0: an ObjectName
	1: an ObjectType
	2: a FullObjectPath
	3: (creation_time) a Timestamp
	4: an ObjectID
	5: (object_owner) a Username
	6: an ObjectSize
	7: a UserMetadata
	8: an AutoMetadata
	9: (user_permission) a WorkspacePerm
	10: (global_permission) a WorkspacePerm
	11: (shockurl) a string
ObjectName is a string
ObjectType is a string
FullObjectPath is a string
Timestamp is a string
ObjectID is a string
Username is a string
ObjectSize is an int
UserMetadata is a reference to a hash where the key is a string and the value is a string
AutoMetadata is a reference to a hash where the key is a string and the value is a string
WorkspacePerm is a string


=end text

=item Description



=back

=cut

sub copy_genome
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function copy_genome (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to copy_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.copy_genome",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking copy_genome:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method copy_genome: " .  $self->{client}->status_line;
    }
}



=head2 list_model_edits

  $output = $obj->list_model_edits($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a list_model_edits_params
$output is a reference to a list where each element is a simple_edit_output
list_model_edits_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
simple_edit_output is a reference to a hash where the following keys are defined:
	id has a value which is an edit_id
	timestamp has a value which is a Timestamp
	reactions_removed has a value which is a reference to a list where each element is a string
	reactions_added has a value which is a reference to a list where each element is a string
	reactions_modified has a value which is a reference to a list where each element is a string
	biomass_added has a value which is a reference to a list where each element is a string
	biomass_changed has a value which is a reference to a list where each element is a string
	biomass_removed has a value which is a reference to a list where each element is a string
edit_id is a string
Timestamp is a string

</pre>

=end html

=begin text

$input is a list_model_edits_params
$output is a reference to a list where each element is a simple_edit_output
list_model_edits_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
simple_edit_output is a reference to a hash where the following keys are defined:
	id has a value which is an edit_id
	timestamp has a value which is a Timestamp
	reactions_removed has a value which is a reference to a list where each element is a string
	reactions_added has a value which is a reference to a list where each element is a string
	reactions_modified has a value which is a reference to a list where each element is a string
	biomass_added has a value which is a reference to a list where each element is a string
	biomass_changed has a value which is a reference to a list where each element is a string
	biomass_removed has a value which is a reference to a list where each element is a string
edit_id is a string
Timestamp is a string


=end text

=item Description



=back

=cut

sub list_model_edits
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function list_model_edits (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to list_model_edits:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.list_model_edits",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking list_model_edits:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method list_model_edits: " .  $self->{client}->status_line;
    }
}



=head2 edit_model

  $output = $obj->edit_model($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an edit_model_params
$output is a detailed_edit_output
edit_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	biomass_changes has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (biomass_id) a string
	1: (compound_id) a string
	2: (coefficient) a float

	reactions_to_remove has a value which is a reference to a list where each element is a string
	reactions_to_add has a value which is a reference to a list where each element is a reference to a list containing 9 items:
	0: (reaction_id) a string
	1: (compartment) a string
	2: (direction) a string
	3: (gpr) a string
	4: (pathway) a string
	5: (name) a string
	6: (reference) a string
	7: (enzyme) a string
	8: (equation) a string

	reactions_to_modify has a value which is a reference to a list where each element is a reference to a list containing 7 items:
	0: (reaction_id) a string
	1: (direction) a string
	2: (gpr) a string
	3: (pathway) a string
	4: (name) a string
	5: (reference) a string
	6: (enzyme) a string

reference is a string
detailed_edit_output is a reference to a hash where the following keys are defined:
	id has a value which is an edit_id
	timestamp has a value which is a Timestamp
	reactions_removed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	reactions_added has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	reactions_modified has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	biomass_added has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	biomass_changed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	biomass_removed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
edit_id is a string
Timestamp is a string

</pre>

=end html

=begin text

$input is an edit_model_params
$output is a detailed_edit_output
edit_model_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
	biomass_changes has a value which is a reference to a list where each element is a reference to a list containing 3 items:
	0: (biomass_id) a string
	1: (compound_id) a string
	2: (coefficient) a float

	reactions_to_remove has a value which is a reference to a list where each element is a string
	reactions_to_add has a value which is a reference to a list where each element is a reference to a list containing 9 items:
	0: (reaction_id) a string
	1: (compartment) a string
	2: (direction) a string
	3: (gpr) a string
	4: (pathway) a string
	5: (name) a string
	6: (reference) a string
	7: (enzyme) a string
	8: (equation) a string

	reactions_to_modify has a value which is a reference to a list where each element is a reference to a list containing 7 items:
	0: (reaction_id) a string
	1: (direction) a string
	2: (gpr) a string
	3: (pathway) a string
	4: (name) a string
	5: (reference) a string
	6: (enzyme) a string

reference is a string
detailed_edit_output is a reference to a hash where the following keys are defined:
	id has a value which is an edit_id
	timestamp has a value which is a Timestamp
	reactions_removed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	reactions_added has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	reactions_modified has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	biomass_added has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	biomass_changed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
	biomass_removed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
edit_id is a string
Timestamp is a string


=end text

=item Description



=back

=cut

sub edit_model
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function edit_model (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to edit_model:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.edit_model",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking edit_model:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method edit_model: " .  $self->{client}->status_line;
    }
}



=head2 get_feature

  $output = $obj->get_feature($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_feature_params
$output is a feature_data
get_feature_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
	feature has a value which is a feature_id
reference is a string
feature_id is a string
feature_data is a reference to a hash where the following keys are defined:
	id has a value which is a feature_id
	function has a value which is a string
	protein_translation has a value which is a string
	subsystems has a value which is a reference to a list where each element is a string
	plant_similarities has a value which is a reference to a list where each element is a similarity
	prokaryotic_similarities has a value which is a reference to a list where each element is a similarity
similarity is a reference to a hash where the following keys are defined:
	hit_id has a value which is a string
	percent_id has a value which is a float
	e_value has a value which is a float
	bit_score has a value which is an int

</pre>

=end html

=begin text

$input is a get_feature_params
$output is a feature_data
get_feature_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
	feature has a value which is a feature_id
reference is a string
feature_id is a string
feature_data is a reference to a hash where the following keys are defined:
	id has a value which is a feature_id
	function has a value which is a string
	protein_translation has a value which is a string
	subsystems has a value which is a reference to a list where each element is a string
	plant_similarities has a value which is a reference to a list where each element is a similarity
	prokaryotic_similarities has a value which is a reference to a list where each element is a similarity
similarity is a reference to a hash where the following keys are defined:
	hit_id has a value which is a string
	percent_id has a value which is a float
	e_value has a value which is a float
	bit_score has a value which is an int


=end text

=item Description



=back

=cut

sub get_feature
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function get_feature (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to get_feature:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.get_feature",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking get_feature:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method get_feature: " .  $self->{client}->status_line;
    }
}



=head2 save_feature_function

  $obj->save_feature_function($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a save_feature_function_params
save_feature_function_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
	feature has a value which is a feature_id
	function has a value which is a string
reference is a string
feature_id is a string

</pre>

=end html

=begin text

$input is a save_feature_function_params
save_feature_function_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
	feature has a value which is a feature_id
	function has a value which is a string
reference is a string
feature_id is a string


=end text

=item Description



=back

=cut

sub save_feature_function
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function save_feature_function (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to save_feature_function:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.save_feature_function",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking save_feature_function:\n$msg\n";
	} else {
	    return;
	}
    } else {
	die "Error invoking method save_feature_function: " .  $self->{client}->status_line;
    }
}



=head2 compare_regions

  $output = $obj->compare_regions($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a get_feature_params
$output is a regions_data
get_feature_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
	feature has a value which is a feature_id
reference is a string
feature_id is a string
regions_data is a reference to a hash where the following keys are defined:
	size has a value which is an int
	number has a value which is an int
	regions has a value which is a reference to a hash where the key is a string and the value is a region
region is a reference to a hash where the following keys are defined:
	id has a value which is a string
	name has a value which is a string
	begin has a value which is an int
	end has a value which is an int
	features has a value which is a reference to a list where each element is a feature
feature is a reference to a hash where the following keys are defined:
	id has a value which is a string
	type has a value which is a string
	function has a value which is a string
	aliases has a value which is a string
	contig has a value which is a string
	begin has a value which is an int
	end has a value which is an int

</pre>

=end html

=begin text

$input is a get_feature_params
$output is a regions_data
get_feature_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
	feature has a value which is a feature_id
reference is a string
feature_id is a string
regions_data is a reference to a hash where the following keys are defined:
	size has a value which is an int
	number has a value which is an int
	regions has a value which is a reference to a hash where the key is a string and the value is a region
region is a reference to a hash where the following keys are defined:
	id has a value which is a string
	name has a value which is a string
	begin has a value which is an int
	end has a value which is an int
	features has a value which is a reference to a list where each element is a feature
feature is a reference to a hash where the following keys are defined:
	id has a value which is a string
	type has a value which is a string
	function has a value which is a string
	aliases has a value which is a string
	contig has a value which is a string
	begin has a value which is an int
	end has a value which is an int


=end text

=item Description



=back

=cut

sub compare_regions
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function compare_regions (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to compare_regions:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.compare_regions",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking compare_regions:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method compare_regions: " .  $self->{client}->status_line;
    }
}



=head2 plant_annotation_overview

  $output = $obj->plant_annotation_overview($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a plant_annotation_overview_params
$output is an annotation_overview
plant_annotation_overview_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
reference is a string
annotation_overview is a reference to a hash where the following keys are defined:
	roles has a value which is a reference to a hash where the key is a string and the value is a reference to a hash where the key is a string and the value is a reference to a list where each element is a feature
feature is a reference to a hash where the following keys are defined:
	id has a value which is a string
	type has a value which is a string
	function has a value which is a string
	aliases has a value which is a string
	contig has a value which is a string
	begin has a value which is an int
	end has a value which is an int

</pre>

=end html

=begin text

$input is a plant_annotation_overview_params
$output is an annotation_overview
plant_annotation_overview_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
reference is a string
annotation_overview is a reference to a hash where the following keys are defined:
	roles has a value which is a reference to a hash where the key is a string and the value is a reference to a hash where the key is a string and the value is a reference to a list where each element is a feature
feature is a reference to a hash where the following keys are defined:
	id has a value which is a string
	type has a value which is a string
	function has a value which is a string
	aliases has a value which is a string
	contig has a value which is a string
	begin has a value which is an int
	end has a value which is an int


=end text

=item Description



=back

=cut

sub plant_annotation_overview
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function plant_annotation_overview (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to plant_annotation_overview:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.plant_annotation_overview",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking plant_annotation_overview:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method plant_annotation_overview: " .  $self->{client}->status_line;
    }
}



=head2 create_genome_from_shock

  $output = $obj->create_genome_from_shock($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a create_genome_from_shock_params
$output is a string
create_genome_from_shock_params is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string
	destname has a value which is a string

</pre>

=end html

=begin text

$input is a create_genome_from_shock_params
$output is a string
create_genome_from_shock_params is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string
	destname has a value which is a string


=end text

=item Description



=back

=cut

sub create_genome_from_shock
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function create_genome_from_shock (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to create_genome_from_shock:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.create_genome_from_shock",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking create_genome_from_shock:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method create_genome_from_shock: " .  $self->{client}->status_line;
    }
}



=head2 plant_pipeline

  $output = $obj->plant_pipeline($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a plant_pipeline_params
$output is a string
plant_pipeline_params is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string
	destname has a value which is a string

</pre>

=end html

=begin text

$input is a plant_pipeline_params
$output is a string
plant_pipeline_params is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string
	destname has a value which is a string


=end text

=item Description



=back

=cut

sub plant_pipeline
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function plant_pipeline (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to plant_pipeline:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.plant_pipeline",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking plant_pipeline:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method plant_pipeline: " .  $self->{client}->status_line;
    }
}



=head2 annotate_plant_genome

  $output = $obj->annotate_plant_genome($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an annotate_plant_genome_params
$output is a string
annotate_plant_genome_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
reference is a string

</pre>

=end html

=begin text

$input is an annotate_plant_genome_params
$output is a string
annotate_plant_genome_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
reference is a string


=end text

=item Description



=back

=cut

sub annotate_plant_genome
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function annotate_plant_genome (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to annotate_plant_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.annotate_plant_genome",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking annotate_plant_genome:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method annotate_plant_genome: " .  $self->{client}->status_line;
    }
}



=head2 create_featurevalues_from_shock

  $output = $obj->create_featurevalues_from_shock($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a create_featurevalues_from_shock_params
$output is a string
create_featurevalues_from_shock_params is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string

</pre>

=end html

=begin text

$input is a create_featurevalues_from_shock_params
$output is a string
create_featurevalues_from_shock_params is a reference to a hash where the following keys are defined:
	shock_id has a value which is a string


=end text

=item Description



=back

=cut

sub create_featurevalues_from_shock
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function create_featurevalues_from_shock (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to create_featurevalues_from_shock:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.create_featurevalues_from_shock",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking create_featurevalues_from_shock:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method create_featurevalues_from_shock: " .  $self->{client}->status_line;
    }
}



=head2 ModelReconstruction

  $output = $obj->ModelReconstruction($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a ModelReconstruction_params
$output is a JobID
ModelReconstruction_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
reference is a string
JobID is a string

</pre>

=end html

=begin text

$input is a ModelReconstruction_params
$output is a JobID
ModelReconstruction_params is a reference to a hash where the following keys are defined:
	genome has a value which is a reference
reference is a string
JobID is a string


=end text

=item Description



=back

=cut

sub ModelReconstruction
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function ModelReconstruction (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to ModelReconstruction:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.ModelReconstruction",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking ModelReconstruction:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method ModelReconstruction: " .  $self->{client}->status_line;
    }
}



=head2 FluxBalanceAnalysis

  $output = $obj->FluxBalanceAnalysis($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a FluxBalanceAnalysis_params
$output is a JobID
FluxBalanceAnalysis_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
JobID is a string

</pre>

=end html

=begin text

$input is a FluxBalanceAnalysis_params
$output is a JobID
FluxBalanceAnalysis_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
JobID is a string


=end text

=item Description



=back

=cut

sub FluxBalanceAnalysis
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function FluxBalanceAnalysis (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to FluxBalanceAnalysis:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.FluxBalanceAnalysis",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking FluxBalanceAnalysis:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method FluxBalanceAnalysis: " .  $self->{client}->status_line;
    }
}



=head2 GapfillModel

  $output = $obj->GapfillModel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a GapfillModel_params
$output is a JobID
GapfillModel_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
JobID is a string

</pre>

=end html

=begin text

$input is a GapfillModel_params
$output is a JobID
GapfillModel_params is a reference to a hash where the following keys are defined:
	model has a value which is a reference
reference is a string
JobID is a string


=end text

=item Description



=back

=cut

sub GapfillModel
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function GapfillModel (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to GapfillModel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.GapfillModel",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking GapfillModel:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method GapfillModel: " .  $self->{client}->status_line;
    }
}



=head2 MergeModels

  $output = $obj->MergeModels($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a MergeModels_params
$output is a JobID
MergeModels_params is a reference to a hash where the following keys are defined:
	models has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (model) a reference
	1: (abundance) a float

	output_file has a value which is a string
	output_path has a value which is a string
reference is a string
JobID is a string

</pre>

=end html

=begin text

$input is a MergeModels_params
$output is a JobID
MergeModels_params is a reference to a hash where the following keys are defined:
	models has a value which is a reference to a list where each element is a reference to a list containing 2 items:
	0: (model) a reference
	1: (abundance) a float

	output_file has a value which is a string
	output_path has a value which is a string
reference is a string
JobID is a string


=end text

=item Description



=back

=cut

sub MergeModels
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function MergeModels (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to MergeModels:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.MergeModels",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking MergeModels:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method MergeModels: " .  $self->{client}->status_line;
    }
}



=head2 ImportKBaseModel

  $output = $obj->ImportKBaseModel($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is an ImportKBaseModel_params
$output is a JobID
ImportKBaseModel_params is a reference to a hash where the following keys are defined:
	kbws has a value which is a string
	kbid has a value which is a string
	kbwsurl has a value which is a string
	kbuser has a value which is a string
	kbpassword has a value which is a string
	kbtoken has a value which is a string
	output_file has a value which is a string
	output_path has a value which is a string
JobID is a string

</pre>

=end html

=begin text

$input is an ImportKBaseModel_params
$output is a JobID
ImportKBaseModel_params is a reference to a hash where the following keys are defined:
	kbws has a value which is a string
	kbid has a value which is a string
	kbwsurl has a value which is a string
	kbuser has a value which is a string
	kbpassword has a value which is a string
	kbtoken has a value which is a string
	output_file has a value which is a string
	output_path has a value which is a string
JobID is a string


=end text

=item Description



=back

=cut

sub ImportKBaseModel
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function ImportKBaseModel (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to ImportKBaseModel:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.ImportKBaseModel",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking ImportKBaseModel:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method ImportKBaseModel: " .  $self->{client}->status_line;
    }
}



=head2 CheckJobs

  $output = $obj->CheckJobs($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a CheckJobs_params
$output is a reference to a hash where the key is a JobID and the value is a Task
CheckJobs_params is a reference to a hash where the following keys are defined:
	jobs has a value which is a reference to a list where each element is a JobID
	include_completed has a value which is a bool
	include_failed has a value which is a bool
	include_running has a value which is a bool
	include_errors has a value which is a bool
	include_queued has a value which is a bool
JobID is a string
bool is an int
Task is a reference to a hash where the following keys are defined:
	id has a value which is a JobID
	app has a value which is a string
	parameters has a value which is a reference to a hash where the key is a string and the value is a string
	status has a value which is a string
	submit_time has a value which is a string
	start_time has a value which is a string
	completed_time has a value which is a string
	stdout_shock_node has a value which is a string
	stderr_shock_node has a value which is a string

</pre>

=end html

=begin text

$input is a CheckJobs_params
$output is a reference to a hash where the key is a JobID and the value is a Task
CheckJobs_params is a reference to a hash where the following keys are defined:
	jobs has a value which is a reference to a list where each element is a JobID
	include_completed has a value which is a bool
	include_failed has a value which is a bool
	include_running has a value which is a bool
	include_errors has a value which is a bool
	include_queued has a value which is a bool
JobID is a string
bool is an int
Task is a reference to a hash where the following keys are defined:
	id has a value which is a JobID
	app has a value which is a string
	parameters has a value which is a reference to a hash where the key is a string and the value is a string
	status has a value which is a string
	submit_time has a value which is a string
	start_time has a value which is a string
	completed_time has a value which is a string
	stdout_shock_node has a value which is a string
	stderr_shock_node has a value which is a string


=end text

=item Description



=back

=cut

sub CheckJobs
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function CheckJobs (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to CheckJobs:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.CheckJobs",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking CheckJobs:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method CheckJobs: " .  $self->{client}->status_line;
    }
}



=head2 ManageJobs

  $output = $obj->ManageJobs($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a ManageJobs_params
$output is a reference to a hash where the key is a JobID and the value is a Task
ManageJobs_params is a reference to a hash where the following keys are defined:
	jobs has a value which is a reference to a list where each element is a JobID
	action has a value which is a string
	errors has a value which is a reference to a hash where the key is a string and the value is a string
	reports has a value which is a reference to a hash where the key is a string and the value is a string
JobID is a string
Task is a reference to a hash where the following keys are defined:
	id has a value which is a JobID
	app has a value which is a string
	parameters has a value which is a reference to a hash where the key is a string and the value is a string
	status has a value which is a string
	submit_time has a value which is a string
	start_time has a value which is a string
	completed_time has a value which is a string
	stdout_shock_node has a value which is a string
	stderr_shock_node has a value which is a string

</pre>

=end html

=begin text

$input is a ManageJobs_params
$output is a reference to a hash where the key is a JobID and the value is a Task
ManageJobs_params is a reference to a hash where the following keys are defined:
	jobs has a value which is a reference to a list where each element is a JobID
	action has a value which is a string
	errors has a value which is a reference to a hash where the key is a string and the value is a string
	reports has a value which is a reference to a hash where the key is a string and the value is a string
JobID is a string
Task is a reference to a hash where the following keys are defined:
	id has a value which is a JobID
	app has a value which is a string
	parameters has a value which is a reference to a hash where the key is a string and the value is a string
	status has a value which is a string
	submit_time has a value which is a string
	start_time has a value which is a string
	completed_time has a value which is a string
	stdout_shock_node has a value which is a string
	stderr_shock_node has a value which is a string


=end text

=item Description



=back

=cut

sub ManageJobs
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function ManageJobs (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to ManageJobs:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.ManageJobs",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking ManageJobs:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method ManageJobs: " .  $self->{client}->status_line;
    }
}



=head2 CreateJobs

  $output = $obj->CreateJobs($input)

=over 4

=item Parameter and return types

=begin html

<pre>
$input is a CreateJobs_params
$output is a reference to a hash where the key is a JobID and the value is a Task
CreateJobs_params is a reference to a hash where the following keys are defined:
	jobs has a value which is a reference to a list where each element is a Task
Task is a reference to a hash where the following keys are defined:
	id has a value which is a JobID
	app has a value which is a string
	parameters has a value which is a reference to a hash where the key is a string and the value is a string
	status has a value which is a string
	submit_time has a value which is a string
	start_time has a value which is a string
	completed_time has a value which is a string
	stdout_shock_node has a value which is a string
	stderr_shock_node has a value which is a string
JobID is a string

</pre>

=end html

=begin text

$input is a CreateJobs_params
$output is a reference to a hash where the key is a JobID and the value is a Task
CreateJobs_params is a reference to a hash where the following keys are defined:
	jobs has a value which is a reference to a list where each element is a Task
Task is a reference to a hash where the following keys are defined:
	id has a value which is a JobID
	app has a value which is a string
	parameters has a value which is a reference to a hash where the key is a string and the value is a string
	status has a value which is a string
	submit_time has a value which is a string
	start_time has a value which is a string
	completed_time has a value which is a string
	stdout_shock_node has a value which is a string
	stderr_shock_node has a value which is a string
JobID is a string


=end text

=item Description



=back

=cut

sub CreateJobs
{
    my($self, @args) = @_;

# Authentication: required

    if ((my $n = @args) != 1)
    {
        die "Invalid argument count for function CreateJobs (received $n, expecting 1)";
    }
    {
	my($input) = @args;

	my @_bad_arguments;
        (ref($input) eq 'HASH') or push(@_bad_arguments, "Invalid type for argument 1 \"input\" (value was \"$input\")");
        if (@_bad_arguments) {
	    my $msg = "Invalid arguments passed to CreateJobs:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	    die $msg;
	}
    }

    my $result = $self->{client}->call($self->{url}, $self->{headers}, {
	method => "ProbModelSEED.CreateJobs",
	params => \@args,
    });
    if ($result) {
	if ($result->{error}) {
	    my $msg = $result->{error}->{error} || $result->{error}->{message};
	    $msg =  $self->{client}->json->encode($msg) if ref($msg);
	    die "Error $result->{error}->{code} invoking CreateJobs:\n$msg\n";
	} else {
	    return wantarray ? @{$result->{result}} : $result->{result}->[0];
	}
    } else {
	die "Error invoking method CreateJobs: " .  $self->{client}->status_line;
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



=head2 reference

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



=head2 Timestamp

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



=head2 gapfill_id

=over 4



=item Description

ID of gapfilling solution


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



=head2 fba_id

=over 4



=item Description

ID of FBA study


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



=head2 edit_id

=over 4



=item Description

ID of model edits


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



=head2 gapfill_command

=over 4



=item Description

An enum of commands to manage gapfilling solutions [D/I/U]; D = delete, I = integrate, U = unintegrate


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



=head2 reaction_id

=over 4



=item Description

ID of reaction in model


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



=head2 compound_id

=over 4



=item Description

ID of compound in model


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



=head2 feature_id

=over 4



=item Description

ID of feature in model


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



=head2 compartment_id

=over 4



=item Description

ID of compartment in model


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



=head2 gene_id

=over 4



=item Description

ID of gene in model


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



=head2 biomass_id

=over 4



=item Description

ID of biomass reaction in model


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



=head2 reaction_direction

=over 4



=item Description

An enum of directions for reactions [</=/>]; < = reverse, = = reversible, > = forward


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



=head2 Username

=over 4



=item Description

Login name for user


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



=head2 ObjectName

=over 4



=item Description

Name assigned to an object saved to a workspace


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



=head2 ObjectID

=over 4



=item Description

Unique UUID assigned to every object in a workspace on save - IDs never reused


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



=head2 ObjectType

=over 4



=item Description

Specified type of an object (e.g. Genome)


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



=head2 ObjectSize

=over 4



=item Description

Size of the object


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



=head2 ObjectData

=over 4



=item Description

Generic type containing object data


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



=head2 FullObjectPath

=over 4



=item Description

Path to any object in workspace database


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



=head2 UserMetadata

=over 4



=item Description

This is a key value hash of user-specified metadata


=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a string
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a string

=end text

=back



=head2 AutoMetadata

=over 4



=item Description

This is a key value hash of automated metadata populated based on object type


=item Definition

=begin html

<pre>
a reference to a hash where the key is a string and the value is a string
</pre>

=end html

=begin text

a reference to a hash where the key is a string and the value is a string

=end text

=back



=head2 WorkspacePerm

=over 4



=item Description

User permission in worksace (e.g. w - write, r - read, a - admin, n - none)


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



=head2 JobID

=over 4



=item Description

ID of job running in app service


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



=head2 gapfill_reaction

=over 4



=item Description

********************************************************************************
    Complex data structures to support functions
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
reaction has a value which is a reference
direction has a value which is a reaction_direction
compartment has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
reaction has a value which is a reference
direction has a value which is a reaction_direction
compartment has a value which is a string


=end text

=back



=head2 gapfill_data

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
rundate has a value which is a Timestamp
id has a value which is a gapfill_id
ref has a value which is a reference
media_ref has a value which is a reference
integrated has a value which is a bool
integrated_solution has a value which is an int
solution_reactions has a value which is a reference to a list where each element is a reference to a list where each element is a gapfill_reaction

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
rundate has a value which is a Timestamp
id has a value which is a gapfill_id
ref has a value which is a reference
media_ref has a value which is a reference
integrated has a value which is a bool
integrated_solution has a value which is an int
solution_reactions has a value which is a reference to a list where each element is a reference to a list where each element is a gapfill_reaction


=end text

=back



=head2 fba_data

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
rundate has a value which is a Timestamp
id has a value which is a fba_id
ref has a value which is a reference
objective has a value which is a float
media_ref has a value which is a reference
objective_function has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
rundate has a value which is a Timestamp
id has a value which is a fba_id
ref has a value which is a reference
objective has a value which is a float
media_ref has a value which is a reference
objective_function has a value which is a string


=end text

=back



=head2 ModelStats

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
rundate has a value which is a Timestamp
id has a value which is a string
source has a value which is a string
source_id has a value which is a string
name has a value which is a string
type has a value which is a string
ref has a value which is a reference
genome_ref has a value which is a reference
template_ref has a value which is a reference
fba_count has a value which is an int
integrated_gapfills has a value which is an int
unintegrated_gapfills has a value which is an int
gene_associated_reactions has a value which is an int
gapfilled_reactions has a value which is an int
num_genes has a value which is an int
num_compounds has a value which is an int
num_reactions has a value which is an int
num_biomasses has a value which is an int
num_biomass_compounds has a value which is an int
num_compartments has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
rundate has a value which is a Timestamp
id has a value which is a string
source has a value which is a string
source_id has a value which is a string
name has a value which is a string
type has a value which is a string
ref has a value which is a reference
genome_ref has a value which is a reference
template_ref has a value which is a reference
fba_count has a value which is an int
integrated_gapfills has a value which is an int
unintegrated_gapfills has a value which is an int
gene_associated_reactions has a value which is an int
gapfilled_reactions has a value which is an int
num_genes has a value which is an int
num_compounds has a value which is an int
num_reactions has a value which is an int
num_biomasses has a value which is an int
num_biomass_compounds has a value which is an int
num_compartments has a value which is an int


=end text

=back



=head2 model_reaction

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a reaction_id
name has a value which is a string
stoichiometry has a value which is a reference to a list where each element is a reference to a list containing 5 items:
0: (coefficient) a float
1: (id) a compound_id
2: (compartment) a compartment_id
3: (compartment_index) an int
4: (name) a string

direction has a value which is a string
gpr has a value which is a string
genes has a value which is a reference to a list where each element is a gene_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a reaction_id
name has a value which is a string
stoichiometry has a value which is a reference to a list where each element is a reference to a list containing 5 items:
0: (coefficient) a float
1: (id) a compound_id
2: (compartment) a compartment_id
3: (compartment_index) an int
4: (name) a string

direction has a value which is a string
gpr has a value which is a string
genes has a value which is a reference to a list where each element is a gene_id


=end text

=back



=head2 model_compound

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a compound_id
name has a value which is a string
formula has a value which is a string
charge has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a compound_id
name has a value which is a string
formula has a value which is a string
charge has a value which is a float


=end text

=back



=head2 model_gene

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a gene_id
reactions has a value which is a reference to a list where each element is a reaction_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a gene_id
reactions has a value which is a reference to a list where each element is a reaction_id


=end text

=back



=head2 model_compartment

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a compartment_id
name has a value which is a string
pH has a value which is a float
potential has a value which is a float

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a compartment_id
name has a value which is a string
pH has a value which is a float
potential has a value which is a float


=end text

=back



=head2 model_biomass

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a biomass_id
compounds has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (compound) a compound_id
1: (coefficient) a float
2: (compartment) a compartment_id


</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a biomass_id
compounds has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (compound) a compound_id
1: (coefficient) a float
2: (compartment) a compartment_id



=end text

=back



=head2 model_data

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
ref has a value which is a reference
reactions has a value which is a reference to a list where each element is a model_reaction
compounds has a value which is a reference to a list where each element is a model_compound
genes has a value which is a reference to a list where each element is a model_gene
compartments has a value which is a reference to a list where each element is a model_compartment
biomasses has a value which is a reference to a list where each element is a model_biomass

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
ref has a value which is a reference
reactions has a value which is a reference to a list where each element is a model_reaction
compounds has a value which is a reference to a list where each element is a model_compound
genes has a value which is a reference to a list where each element is a model_gene
compartments has a value which is a reference to a list where each element is a model_compartment
biomasses has a value which is a reference to a list where each element is a model_biomass


=end text

=back



=head2 ObjectMeta

=over 4



=item Description

ObjectMeta: tuple containing information about an object in the workspace 

       ObjectName - name selected for object in workspace
       ObjectType - type of the object in the workspace
       FullObjectPath - full path to object in workspace, including object name
       Timestamp creation_time - time when the object was created
       ObjectID - a globally unique UUID assigned to every object that will never change even if the object is moved
       Username object_owner - name of object owner
       ObjectSize - size of the object in bytes or if object is directory, the number of objects in directory
       UserMetadata - arbitrary user metadata associated with object
       AutoMetadata - automatically populated metadata generated from object data in automated way
       WorkspacePerm user_permission - permissions for the authenticated user of this workspace.
       WorkspacePerm global_permission - whether this workspace is globally readable.
       string shockurl - shockurl included if object is a reference to a shock node


=item Definition

=begin html

<pre>
a reference to a list containing 12 items:
0: an ObjectName
1: an ObjectType
2: a FullObjectPath
3: (creation_time) a Timestamp
4: an ObjectID
5: (object_owner) a Username
6: an ObjectSize
7: a UserMetadata
8: an AutoMetadata
9: (user_permission) a WorkspacePerm
10: (global_permission) a WorkspacePerm
11: (shockurl) a string

</pre>

=end html

=begin text

a reference to a list containing 12 items:
0: an ObjectName
1: an ObjectType
2: a FullObjectPath
3: (creation_time) a Timestamp
4: an ObjectID
5: (object_owner) a Username
6: an ObjectSize
7: a UserMetadata
8: an AutoMetadata
9: (user_permission) a WorkspacePerm
10: (global_permission) a WorkspacePerm
11: (shockurl) a string


=end text

=back



=head2 list_gapfill_solutions_params

=over 4



=item Description

********************************************************************************
    Functions for managing gapfilling studies
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference


=end text

=back



=head2 manage_gapfill_solutions_params

=over 4



=item Description

FUNCTION: manage_gapfill_solutions
                DESCRIPTION: This function manages the gapfill solutions for a model and returns gapfill solution data
                
                REQUIRED INPUTS:
                reference model - reference to model to integrate solutions for
                mapping<gapfill_id,gapfill_command> commands - commands to manage gapfill solutions
                
                OPTIONAL INPUTS:
                mapping<gapfill_id,int> selected_solutions - solutions to integrate


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference
commands has a value which is a reference to a hash where the key is a gapfill_id and the value is a gapfill_command
selected_solutions has a value which is a reference to a hash where the key is a gapfill_id and the value is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference
commands has a value which is a reference to a hash where the key is a gapfill_id and the value is a gapfill_command
selected_solutions has a value which is a reference to a hash where the key is a gapfill_id and the value is an int


=end text

=back



=head2 list_fba_studies_params

=over 4



=item Description

********************************************************************************
    Functions for managing FBA studies
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference


=end text

=back



=head2 delete_fba_studies_params

=over 4



=item Description

FUNCTION: delete_fba_studies
                DESCRIPTION: This function deletes fba studies associated with model
                
                REQUIRED INPUTS:
                reference model - reference to model to integrate solutions for
                list<fba_id> fbas - list of FBA studies to delete


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference
commands has a value which is a reference to a hash where the key is a gapfill_id and the value is a gapfill_command

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference
commands has a value which is a reference to a hash where the key is a gapfill_id and the value is a gapfill_command


=end text

=back



=head2 export_model_params

=over 4



=item Description

********************************************************************************
    Functions for export of model data
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference
format has a value which is a string
to_shock has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference
format has a value which is a string
to_shock has a value which is a bool


=end text

=back



=head2 export_media_params

=over 4



=item Description

FUNCTION: export_media
                DESCRIPTION: This function exports a media in TSV format
                
                REQUIRED INPUTS:
                reference media - reference to media to export
                bool to_shock - load exported file to shock and return shock url


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
media has a value which is a reference
to_shock has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
media has a value which is a reference
to_shock has a value which is a bool


=end text

=back



=head2 get_model_params

=over 4



=item Description

********************************************************************************
    Functions for managing models
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference


=end text

=back



=head2 delete_model_params

=over 4



=item Description

FUNCTION: delete_model
            DESCRIPTION: This function deletes a model specified by the user
            
            REQUIRED INPUTS:
                reference model - reference to model to delete


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference


=end text

=back



=head2 list_models_params

=over 4



=item Description

FUNCTION: list_models
            DESCRIPTION: This function lists all models owned by the user
            
            REQUIRED INPUTS:
                
                OPTIONAL INPUTS:
                reference path;


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
path has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
path has a value which is a reference


=end text

=back



=head2 copy_model_params

=over 4



=item Description

FUNCTION: copy_model
            DESCRIPTION: This function copies the specified model to another location or even workspace
            
            REQUIRED INPUTS:
                reference model - reference to model to copy
                
                OPTIONAL INPUTS:
                reference destination - location where the model should be copied to
                bool copy_genome - set this to copy the genome associated with the model
                bool to_kbase - set to one to copy the model to KBase
                string workspace_url - URL of workspace to which data should be copied
                string kbase_username - kbase username for copying models to kbase
                string kbase_password - kbase password for copying models to kbase


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference
destination has a value which is a reference
destname has a value which is a string
copy_genome has a value which is a bool
to_kbase has a value which is a bool
workspace_url has a value which is a string
kbase_username has a value which is a string
kbase_password has a value which is a string
plantseed has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference
destination has a value which is a reference
destname has a value which is a string
copy_genome has a value which is a bool
to_kbase has a value which is a bool
workspace_url has a value which is a string
kbase_username has a value which is a string
kbase_password has a value which is a string
plantseed has a value which is a bool


=end text

=back



=head2 copy_genome_params

=over 4



=item Description

FUNCTION: copy_genome
            DESCRIPTION: This function copies the specified genome to another location or even workspace
            
            REQUIRED INPUTS:
                reference genome - reference to genome to copy
                
                OPTIONAL INPUTS:
                reference destination - location where the genome should be copied to
                bool to_kbase - set to one to copy the genome to KBase
                string workspace_url - URL of workspace to which data should be copied
                string kbase_username - kbase username for copying models to kbase
                string kbase_password - kbase password for copying models to kbase


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a reference
destination has a value which is a reference
destname has a value which is a string
to_kbase has a value which is a bool
workspace_url has a value which is a string
kbase_username has a value which is a string
kbase_password has a value which is a string
plantseed has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a reference
destination has a value which is a reference
destname has a value which is a string
to_kbase has a value which is a bool
workspace_url has a value which is a string
kbase_username has a value which is a string
kbase_password has a value which is a string
plantseed has a value which is a bool


=end text

=back



=head2 simple_edit_output

=over 4



=item Description

********************************************************************************
    Functions for editing models
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an edit_id
timestamp has a value which is a Timestamp
reactions_removed has a value which is a reference to a list where each element is a string
reactions_added has a value which is a reference to a list where each element is a string
reactions_modified has a value which is a reference to a list where each element is a string
biomass_added has a value which is a reference to a list where each element is a string
biomass_changed has a value which is a reference to a list where each element is a string
biomass_removed has a value which is a reference to a list where each element is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an edit_id
timestamp has a value which is a Timestamp
reactions_removed has a value which is a reference to a list where each element is a string
reactions_added has a value which is a reference to a list where each element is a string
reactions_modified has a value which is a reference to a list where each element is a string
biomass_added has a value which is a reference to a list where each element is a string
biomass_changed has a value which is a reference to a list where each element is a string
biomass_removed has a value which is a reference to a list where each element is a string


=end text

=back



=head2 detailed_edit_output

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is an edit_id
timestamp has a value which is a Timestamp
reactions_removed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
reactions_added has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
reactions_modified has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
biomass_added has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
biomass_changed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
biomass_removed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is an edit_id
timestamp has a value which is a Timestamp
reactions_removed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
reactions_added has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
reactions_modified has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
biomass_added has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
biomass_changed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string
biomass_removed has a value which is a reference to a list where each element is a reference to a hash where the key is a string and the value is a string


=end text

=back



=head2 list_model_edits_params

=over 4



=item Description

FUNCTION: list_model_edits
            DESCRIPTION: This function lists all model edits submitted by the user
            
            REQUIRED INPUTS:
                reference model - reference to model for which to list edits


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference


=end text

=back



=head2 edit_model_params

=over 4



=item Description

FUNCTION: manage_model_edits
                DESCRIPTION: This function manages edits to model submitted by user
                
                REQUIRED INPUTS:
                reference model - reference to model to integrate solutions for
                mapping<edit_id,gapfill_command> commands - list of edit commands
                
                OPTIONAL INPUTS:
                edit_data new_edit - list of new edits to add


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference
biomass_changes has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (biomass_id) a string
1: (compound_id) a string
2: (coefficient) a float

reactions_to_remove has a value which is a reference to a list where each element is a string
reactions_to_add has a value which is a reference to a list where each element is a reference to a list containing 9 items:
0: (reaction_id) a string
1: (compartment) a string
2: (direction) a string
3: (gpr) a string
4: (pathway) a string
5: (name) a string
6: (reference) a string
7: (enzyme) a string
8: (equation) a string

reactions_to_modify has a value which is a reference to a list where each element is a reference to a list containing 7 items:
0: (reaction_id) a string
1: (direction) a string
2: (gpr) a string
3: (pathway) a string
4: (name) a string
5: (reference) a string
6: (enzyme) a string


</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference
biomass_changes has a value which is a reference to a list where each element is a reference to a list containing 3 items:
0: (biomass_id) a string
1: (compound_id) a string
2: (coefficient) a float

reactions_to_remove has a value which is a reference to a list where each element is a string
reactions_to_add has a value which is a reference to a list where each element is a reference to a list containing 9 items:
0: (reaction_id) a string
1: (compartment) a string
2: (direction) a string
3: (gpr) a string
4: (pathway) a string
5: (name) a string
6: (reference) a string
7: (enzyme) a string
8: (equation) a string

reactions_to_modify has a value which is a reference to a list where each element is a reference to a list containing 7 items:
0: (reaction_id) a string
1: (direction) a string
2: (gpr) a string
3: (pathway) a string
4: (name) a string
5: (reference) a string
6: (enzyme) a string



=end text

=back



=head2 similarity

=over 4



=item Description

********************************************************************************
	Functions corresponding to use of PlantSEED web-pages
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
hit_id has a value which is a string
percent_id has a value which is a float
e_value has a value which is a float
bit_score has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
hit_id has a value which is a string
percent_id has a value which is a float
e_value has a value which is a float
bit_score has a value which is an int


=end text

=back



=head2 feature_data

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a feature_id
function has a value which is a string
protein_translation has a value which is a string
subsystems has a value which is a reference to a list where each element is a string
plant_similarities has a value which is a reference to a list where each element is a similarity
prokaryotic_similarities has a value which is a reference to a list where each element is a similarity

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a feature_id
function has a value which is a string
protein_translation has a value which is a string
subsystems has a value which is a reference to a list where each element is a string
plant_similarities has a value which is a reference to a list where each element is a similarity
prokaryotic_similarities has a value which is a reference to a list where each element is a similarity


=end text

=back



=head2 get_feature_params

=over 4



=item Description

FUNCTION: get_feature
                DESCRIPTION: This function retrieves an individual Plant feature

                REQUIRED INPUTS:
                reference genome - reference of genome that contains feature
                feature_id feature - identifier of feature to get


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a reference
feature has a value which is a feature_id

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a reference
feature has a value which is a feature_id


=end text

=back



=head2 save_feature_function_params

=over 4



=item Description

FUNCTION: save_feature_function
                DESCRIPTION: This function saves the newly assigned function in a feature
                             thereby updating the annotation of a genome

                REQUIRED INPUTS:
                reference genome - reference of genome that contains feature
                feature_id feature - identifier of feature to get
                string function - the new annotation to assign to a feature


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a reference
feature has a value which is a feature_id
function has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a reference
feature has a value which is a feature_id
function has a value which is a string


=end text

=back



=head2 feature

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a string
type has a value which is a string
function has a value which is a string
aliases has a value which is a string
contig has a value which is a string
begin has a value which is an int
end has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a string
type has a value which is a string
function has a value which is a string
aliases has a value which is a string
contig has a value which is a string
begin has a value which is an int
end has a value which is an int


=end text

=back



=head2 region

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a string
name has a value which is a string
begin has a value which is an int
end has a value which is an int
features has a value which is a reference to a list where each element is a feature

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a string
name has a value which is a string
begin has a value which is an int
end has a value which is an int
features has a value which is a reference to a list where each element is a feature


=end text

=back



=head2 regions_data

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
size has a value which is an int
number has a value which is an int
regions has a value which is a reference to a hash where the key is a string and the value is a region

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
size has a value which is an int
number has a value which is an int
regions has a value which is a reference to a hash where the key is a string and the value is a region


=end text

=back



=head2 compare_regions_params

=over 4



=item Description

FUNCTION: compare_regions
                DESCRIPTION: This function retrieves the data required to build the CompareRegions view

                REQUIRED INPUTS:
                list<string> similarities - list of peg identifiers

                OPTIONAL INPUTS:
                int region_size - width of regions (in bp) to cover. Defaults to 15000
                int number_regions - number of regions to show. Defaults to 10


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
similarities has a value which is a reference to a list where each element is a string
region_size has a value which is an int
number_regions has a value which is an int

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
similarities has a value which is a reference to a list where each element is a string
region_size has a value which is an int
number_regions has a value which is an int


=end text

=back



=head2 annotation_overview

=over 4



=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
roles has a value which is a reference to a hash where the key is a string and the value is a reference to a hash where the key is a string and the value is a reference to a list where each element is a feature

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
roles has a value which is a reference to a hash where the key is a string and the value is a reference to a hash where the key is a string and the value is a reference to a list where each element is a feature


=end text

=back



=head2 plant_annotation_overview_params

=over 4



=item Description

FUNCTION: plant_annotation_overview
                DESCRIPTION: This function retrieves the annotation_overview required to summarize a genome PlantSEED annotation

                REQUIRED INPUTS:
                reference genome - annotated genome to explore


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a reference


=end text

=back



=head2 create_genome_from_shock_params

=over 4



=item Description

FUNCTION: create_genome_from_shock
                DESCRIPTION: This function retrieves the fasta file of sequences from shock and creates a genome object

                REQUIRED INPUTS:
                string shock_id - id in shock with which to retrieve fasta file
                string name - name under which to store the genome and resulting model


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
shock_id has a value which is a string
destname has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
shock_id has a value which is a string
destname has a value which is a string


=end text

=back



=head2 plant_pipeline_params

=over 4



=item Description

FUNCTION: plant_pipeline
                DESCRIPTION: This function retrieves the fasta file of sequences from shock and creates a genome object

                REQUIRED INPUTS:
                string shock_id - id in shock with which to retrieve fasta file
                string name - name under which to store the genome and resulting model


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
shock_id has a value which is a string
destname has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
shock_id has a value which is a string
destname has a value which is a string


=end text

=back



=head2 annotate_plant_genome_params

=over 4



=item Description

FUNCTION: annotate_plant_genome
                DESCRIPTION: This function retrieves the sequences from a plantseed genome object and annotates them

                REQUIRED INPUTS:
                reference genome - annotated genome to explore


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a reference


=end text

=back



=head2 create_featurevalues_from_shock_params

=over 4



=item Description

FUNCTION: create_featurevalues_from_shock
                DESCRIPTION: This function retrieves the tsv file from shock and creates a FeatureValues object

                REQUIRED INPUTS:
                string shock_id - id in shock with which to retrieve tsv file


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
shock_id has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
shock_id has a value which is a string


=end text

=back



=head2 ModelReconstruction_params

=over 4



=item Description

********************************************************************************
	Functions corresponding to modeling apps
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
genome has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
genome has a value which is a reference


=end text

=back



=head2 FluxBalanceAnalysis_params

=over 4



=item Description

FUNCTION: FluxBalanceAnalysis
                DESCRIPTION: This function runs the flux balance analysis app directly. See app service for detailed specs.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference


=end text

=back



=head2 GapfillModel_params

=over 4



=item Description

FUNCTION: GapfillModel
                DESCRIPTION: This function runs the gapfilling app directly. See app service for detailed specs.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
model has a value which is a reference

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
model has a value which is a reference


=end text

=back



=head2 MergeModels_params

=over 4



=item Description

FUNCTION: MergeModels
                DESCRIPTION: This function combines multiple FBA models into a single community model


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
models has a value which is a reference to a list where each element is a reference to a list containing 2 items:
0: (model) a reference
1: (abundance) a float

output_file has a value which is a string
output_path has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
models has a value which is a reference to a list where each element is a reference to a list containing 2 items:
0: (model) a reference
1: (abundance) a float

output_file has a value which is a string
output_path has a value which is a string


=end text

=back



=head2 ImportKBaseModel_params

=over 4



=item Description

FUNCTION: ImportKBaseModel
                DESCRIPTION: This function imports a metabolic model from a specified location in KBase


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
kbws has a value which is a string
kbid has a value which is a string
kbwsurl has a value which is a string
kbuser has a value which is a string
kbpassword has a value which is a string
kbtoken has a value which is a string
output_file has a value which is a string
output_path has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
kbws has a value which is a string
kbid has a value which is a string
kbwsurl has a value which is a string
kbuser has a value which is a string
kbpassword has a value which is a string
kbtoken has a value which is a string
output_file has a value which is a string
output_path has a value which is a string


=end text

=back



=head2 Task

=over 4



=item Description

********************************************************************************
	Job management functions
   	********************************************************************************


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
id has a value which is a JobID
app has a value which is a string
parameters has a value which is a reference to a hash where the key is a string and the value is a string
status has a value which is a string
submit_time has a value which is a string
start_time has a value which is a string
completed_time has a value which is a string
stdout_shock_node has a value which is a string
stderr_shock_node has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
id has a value which is a JobID
app has a value which is a string
parameters has a value which is a reference to a hash where the key is a string and the value is a string
status has a value which is a string
submit_time has a value which is a string
start_time has a value which is a string
completed_time has a value which is a string
stdout_shock_node has a value which is a string
stderr_shock_node has a value which is a string


=end text

=back



=head2 CheckJobs_params

=over 4



=item Description

FUNCTION: CheckJobs
                DESCRIPTION: This function checks on the current status of app service jobs


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobs has a value which is a reference to a list where each element is a JobID
include_completed has a value which is a bool
include_failed has a value which is a bool
include_running has a value which is a bool
include_errors has a value which is a bool
include_queued has a value which is a bool

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobs has a value which is a reference to a list where each element is a JobID
include_completed has a value which is a bool
include_failed has a value which is a bool
include_running has a value which is a bool
include_errors has a value which is a bool
include_queued has a value which is a bool


=end text

=back



=head2 ManageJobs_params

=over 4



=item Description

FUNCTION: ManageJobs
                DESCRIPTION: This function supports the deletion and rerunning of jobs
                
                action - character specifying what to do with the job (d - delete, r - run)


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobs has a value which is a reference to a list where each element is a JobID
action has a value which is a string
errors has a value which is a reference to a hash where the key is a string and the value is a string
reports has a value which is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobs has a value which is a reference to a list where each element is a JobID
action has a value which is a string
errors has a value which is a reference to a hash where the key is a string and the value is a string
reports has a value which is a reference to a hash where the key is a string and the value is a string


=end text

=back



=head2 CreateJobs_params

=over 4



=item Description

FUNCTION: CreateJobs
                DESCRIPTION: This function supports the creation of a new job


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
jobs has a value which is a reference to a list where each element is a Task

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
jobs has a value which is a reference to a list where each element is a Task


=end text

=back



=cut

package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient::RpcClient;
use POSIX;
use strict;
use LWP::UserAgent;
use JSON::XS;

BEGIN {
    for my $method (qw/uri ua json content_type version id allow_call status_line/) {
	eval qq|
	    sub $method {
		\$_[0]->{$method} = \$_[1] if defined \$_[1];
		\$_[0]->{$method};
	    }
	    |;
	}
    }

sub new
{
    my($class) = @_;

    my $ua = LWP::UserAgent->new();
    my $json = JSON::XS->new->allow_nonref->utf8;
    
    my $self = {
	ua => $ua,
	json => $json,
    };
    return bless $self, $class;
}

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

    if ($result->is_success || $result->content_type eq 'application/json') {

	my $txt = $result->content;

        return unless($txt); # notification?

	my $obj = eval { $self->json->decode($txt); };

	if (!$obj)
	{
	    die "Error parsing result: $@";
	}

	return $obj;
    }
    else {
        return;
    }
}

sub _get {
    my ($self, $uri) = @_;
    $self->ua->get(
		   $uri,
		   Accept         => 'application/json',
		  );
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
            $obj->{id} = $self->id || ($self->id('JSON::RPC::Legacy::Client'));
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
