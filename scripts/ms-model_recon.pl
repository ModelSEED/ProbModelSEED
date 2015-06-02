use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <genome>",[
	["gapfill|g", "Gapfill model" ],
	["template|t=s", "Template to use in building model"],
	["fulldb|f", "Include entire template in model"],
	["path|p=s", "Path in workspace to save model"],
	["name|n=s", "Name to use for model in workspace"],
]);
if (!defined($opt->{path})) {
	$opt->{path} = "/".Bio::P3::Workspace::ScriptHelpers::user()."/home/models/";
}
if (!defined($opt->{name})) {
	$opt->{name} = $ARGV[0];
	$opt->{name} =~ s/.+\///g;
	$opt->{name} .= ".model";
}
my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$opt->{path}]);
$opt->{path} = $paths->[0];
$paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$ARGV[0]]);
my $genome = $paths->[0];

print Bio::P3::Workspace::ScriptHelpers::appurl()."\n";

my $client = Bio::KBase::AppService::Client->new(Bio::P3::Workspace::ScriptHelpers::appurl(),token => Bio::P3::Workspace::ScriptHelpers::token());
my $task = $client->start_app("ModelReconstruction",{
	genome => $genome,
	template_model => $opt->{template},
	fulldb => $opt->{fulldb},
	output_path => $opt->{path},
	output_file => $opt->{name}
},$opt->{path});
while ($task->{status} ne "failed" && $task->{status} ne "completed") {
	my $res = $client->query_tasks([$task->{id}]);
	$task = $res->{$task->{id}};
	print $task->{status}."\n";
}
print "Task results:\n";
print join("\t", $task->{id}, $task->{app}, $task->{workspace}, $task->{status}, $task->{submit_time}, $task->{completed_time}), "\n";

