package Bio::ModelSEED::patricenv;
use strict;
use warnings;
use Bio::KBase::utilities;

our $ws_client = undef;
our $objects_created = [];
our $arguments = undef;
our $method = undef;

sub initialize_call {
	my ($ctx,$method,$arguments,$pid) = @_;

	Bio::KBase::utilities::read_config({
	    filename => $ENV{KB_DEPLOYMENT_CONFIG},
	    service => "ProbModelSEED"});

	Bio::KBase::utilities::processid($pid);
	Bio::KBase::utilities::arguments($arguments);
	Bio::KBase::utilities::start_time(1);
	Bio::ModelSEED::patricenv::reset_objects_created();
	Bio::KBase::utilities::timestamp(1);
	if (defined($ctx)) {
		Bio::KBase::utilities::set_context($ctx);
	}
	Bio::ModelSEED::patricenv::ws_client({refresh => 1});
	print("Starting ".$method." method.\n");
}

sub method {
	my($input) = @_;
	if (defined($input)) {
		$method = $input;
	}
	return $method;
}

sub arguments {
	my($input) = @_;
	if (defined($input)) {
		$arguments = $input;
	}
	return $arguments;
}

#create_report: creates a report object using the KBaseReport service
sub create_report {
	my($parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,["ref"],{
		output => undef
	});
	my $jobresult = {
		id => Bio::KBase::utilities::processid(),
		end_time => DateTime->now()->datetime(),
		elapsed_time => Bio::KBase::utilities::elapsedtime(),
		message => Bio::KBase::utilities::report_message(),
		html => Bio::KBase::utilities::report_html(),
		start_time => Bio::KBase::utilities::start_time_stamp(),
		app => Bio::ModelSEED::patricenv::method(),
		parameters => Bio::ModelSEED::patricenv::arguments(),
		output_files => $objects_created
	};
	if (ref($parameters->{output})) {
		$jobresult->{job_output} = Bio::KBase::ObjectAPI::utilities::TOJSON($parameters->{output});
	} else {
		$jobresult->{job_output} = $parameters->{output};
	}
	my $listout = Bio::ModelSEED::patricenv::call_ws("create",{
		objects => [[$parameters->{"ref"},"job_result",{},Bio::KBase::ObjectAPI::utilities::TOJSON($jobresult)]],
		overwrite => 1
	});
}

sub create_context_from_client_config {
	my($parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,[],{
		filename => undef,
		setcontext => 1,
		method => "unknown",
		provenance => []
	});
	if (!defined($parameters->{filename})) {
		$parameters->{filename} = glob "~/.patric_config";
		if (defined($ENV{ P3_CLIENT_CONFIG })) {
	    	$parameters->{filename} = $ENV{ P3_CLIENT_CONFIG };
	    } elsif (defined($ENV{ HOME })) {
	    	$parameters->{filename} = $ENV{ HOME }."/.patric_config";
	    }
	}
	Bio::KBase::utilities::read_config({
		filename => $parameters->{filename},
		service => "P3Client"
	});
	return Bio::KBase::utilities::create_context({
		setcontext => $parameters->{setcontext},
		token => Bio::KBase::utilities::conf("P3Client","token"),
		user => Bio::KBase::utilities::conf("P3Client","user_id"),
		provenance => $parameters->{provenance},
		method => $parameters->{method}
	});
}

sub ws_client {
	my($parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,[],{
		refresh => 0
	});
	if ($parameters->{refresh} == 1 || !defined($ws_client)) {
		if (Bio::KBase::utilities::conf("ProbModelSEED","workspace-url") eq "impl") {
			eval {
				require "Bio/P3/Workspace/WorkspaceImpl.pm";
				*Bio::P3::Workspace::ServiceContext = Bio::KBase::utilities::context();
				return Bio::P3::Workspace::WorkspaceImpl->new();
			};
		} else {
			$ws_client = Bio::P3::Workspace::WorkspaceClientExt->new(Bio::KBase::utilities::conf("ProbModelSEED","workspace-url"),token => Bio::KBase::utilities::token());
		}
	}
	return $ws_client;
}

sub administer {
	my ($args) = @_;
	return Bio::ModelSEED::patricenv::ws_client()->administer($args);
}

sub reset_objects_created {
	$objects_created = [];
}

sub call_ws {
	my ($function,$args) = @_;
	$args->{adminmode} =  Bio::KBase::utilities::conf("ProbModelSEED","adminmode");
	my $retryCount = 3;
	my $error;
	my $output;
	while ($retryCount > 0) {
		if ($function eq "create") {
			if (length(Bio::KBase::utilities::conf("ProbModelSEED","setowner")) > 0) {
				$args->{setowner} = Bio::KBase::utilities::conf("ProbModelSEED","setowner");
			}
			$args->{overwrite} = 1;
		}	
		eval {
			$output = Bio::ModelSEED::patricenv::ws_client()->$function($args);
			if ($function eq "create") {
				for (my $i=0; $i < @{$output}; $i++) {
					push(@{$objects_created},{
						"ref" => $output->[$i]->[2]."/".$output->[$i]->[0],
						description => $output->[$i]->[1]
					});
				}
			}
		};
		# If there is a network glitch, wait a second and try again. 
		if ($@) {
			$error = $@;
			if (($error =~ m/HTTP status: 503 Service Unavailable/) ||
			    ($error =~ m/HTTP status: 502 Bad Gateway/)) {
				$retryCount -= 1;
				Bio::KBase::utilities::log("Error putting workspace object ".$error,"error");
				sleep(1);				
			} else {
				$retryCount = 0; # Get out and report the error
			}
		} else {
			last;
		}
	}
	if ($retryCount == 0) {
		Bio::KBase::utilities::error($error);
	}
	return $output;
}

1;
