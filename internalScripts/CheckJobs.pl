use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;

my $msclient = Bio::P3::Workspace::ScriptHelpers::msClient();

my $output = $msclient->CheckJobs({
	jobs => [98455],
	exclude_failed => 0,
	exclude_running => 0,
	exclude_complete => 0,
	exclude_queued => 0,
	admin => 0,
	scheduler => 0
});

print Data::Dumper->Dump([$output]);