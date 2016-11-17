#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Bio::KBase::utilities;
use Bio::ModelSEED::patricenv;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;

$|=1;

my $jobid = $ARGV[0];

Bio::KBase::utilities::read_config({
	service => "ProbModelSEED"
});

open(PID, "> ".Bio::KBase::utilities::conf("Scheduler","jobdirectory")."jobs/".$ARGV[0]."/pid") || die "could not open PID file!"; 
print PID "$$\n"; 
close(PID);
my $filename = Bio::KBase::utilities::conf("Scheduler","jobdirectory")."jobs/".$ARGV[0]."/jobfile.json";
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
}

eval {
	#my $client = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient->new(Bio::KBase::utilities::conf("Scheduler","msurl"),token => $job->{token});
	my $client = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl->new();
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
