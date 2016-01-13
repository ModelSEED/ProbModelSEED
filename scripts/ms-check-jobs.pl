use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o",[
	["jobid|j=s","Job ID to view full details for"],
	["nocomplete|c","Exclude complete jobs"],
	["nofailed|f","Exclude failed jobs"],
	["norunning|r","Exclude running jobs"],
	["errors|e","Include error messages"]
]);
$opt->{return_errors} = $opt->{errors};
$opt->{exclude_failed} = $opt->{nofailed};
$opt->{exclude_running} = $opt->{norunning};
$opt->{exclude_complete} = $opt->{nocomplete};
my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
if (defined($opt->{jobid})) {
	my $jobstatus = $client->CheckJobs({
		jobs => [$opt->{jobid}],
		exclude_failed => $opt->{nofailed},
		exclude_complete => $opt->{nocomplete},
		exclude_running => $opt->{norunning},
		return_errors => $opt->{errors}
	});
	print Data::Dumper->Dump([$jobstatus->{$opt->{jobid}}])."\n";
} else {
	my $jobstatus = $client->CheckJobs({
		exclude_failed => $opt->{nofailed},
		exclude_complete => $opt->{nocomplete},
		exclude_running => $opt->{norunning},
		return_errors => $opt->{errors}
	});
	my $tbl = [];   
	foreach my $task (keys(%{$jobstatus})) {
		my $job = $jobstatus->{$task};
		push(@$tbl, [$job->{id},$job->{app},$job->{status},$job->{submit_time},$job->{start_time},$job->{completed_time},$job->{stdout_shock_node},$job->{stderr_shock_node}]);
	}
	my $table = Text::Table->new(
		"Task","App","Status","Submitted","Started","Completed","Stdout","Stderr"
	);
	$table->load(@{$tbl});
	print $table."\n";
}