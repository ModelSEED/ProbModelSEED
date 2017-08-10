#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Bio::KBase::utilities;
use Bio::ModelSEED::patricenv;
#use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;

$|=1;

my $jobid = $ARGV[0];

Bio::KBase::utilities::read_config({
	service => "ProbModelSEED"
});
Bio::ModelSEED::patricenv::create_context_from_client_config();

my $directory = Bio::KBase::utilities::conf("Scheduler","jobdirectory")."jobs/".$ARGV[0]."/";
my $filename = $directory."jobfile.json";
File::Path::mkpath ($directory);

if (!-e $directory."jobfile.json") {
	my $client = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient->new(Bio::KBase::utilities::conf("Scheduler","msurl"),token => Bio::KBase::utilities::token());
	my $JSON = JSON::XS->new();
	my $output = $client->CheckJobs({
		admin => 1,
		jobs => [$jobid]
	});
	my $data = $JSON->encode($output->{$jobid});
	open(my $fh, ">", $filename) || return;
	print $fh $data;
	close($fh);
}
if (-e $directory."pid") {
	unlink $directory."pid";
}

open(PID, "> ".$directory."pid") || die "could not open PID file!"; 
print PID "$$\n"; 
close(PID);
if (!-e $filename) {
	die "Cannot open ".$filename;
}
open( my $fh, "<", $filename);
my $job;
{
    local $/;
    my $str = <$fh>;
    $job = decode_json $str;
}
close($fh);

Bio::KBase::utilities::setconf("ProbModelSEED","run_as_app",0);

my $errors = {};
eval {
	my $obj = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
		token => $job->{token},
		username => $job->{owner},
		method => $job->{app},
		parameters => $job->{parameters},
	});
	$obj->app_harness($job->{app},$job->{parameters});
};
if ($@) {
    $errors->{$job->{id}} = $@;
    if ($job->{app} eq "ModelReconstruction") {
    	my $input = $job->{parameters};
    	if (!defined($input->{output_file})) {
	    	$input->{output_file} = $input->{genome};
	    	$input->{output_file} =~ s/.+://;
	    	$input->{output_file} =~ s/.+\///;
    	}
	    if (!defined($input->{output_path})) {
	    	if ($input->{plant} != 0) {
	    		$input->{output_path} = "/".Bio::KBase::utilities::user_id()."/".Bio::KBase::utilities::conf("ProbModelSEED","plantseed_home_dir")."/";
	    	} else {
	    		$input->{output_path} = "/".Bio::KBase::utilities::user_id()."/".Bio::KBase::utilities::conf("ProbModelSEED","home_dir")."/";
	    	}
	    }
	    if (substr($input->{output_path},-1,1) ne "/") {
	    	$input->{output_path} .= "/";
	    }
	    my $folder = $input->{output_path}."/".$input->{output_file};
    	Bio::ModelSEED::patricenv::call_ws("create",{
			objects => [[$folder,"modelfolder",{status_error => $errors->{$job->{id}},status => "failed",status_timestamp => Bio::KBase::utilities::timestamp()},undef]]
		});
    }
}

eval {
	#my $client = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl->new();
	my $client = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient->new(Bio::KBase::utilities::conf("Scheduler","msurl"),token => $job->{token});
	my $jobs = $client->ManageJobs({
		jobs => [$ARGV[0]],
		action => "finish",
		errors => $errors
	});
};
if ($@) {
    die "Error resetting job status:\n".$@;
}

1;
