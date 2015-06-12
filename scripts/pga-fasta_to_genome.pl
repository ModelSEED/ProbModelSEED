use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <contigs path> <scientific name>",[
	["fromfile|f", "Load fasta from file"],
	["domain|d=s", "Domain of life for genome", { "default" => "Bacteria" }],
	["code|c=s", "Genetic code of genome", { "default" => 11 }],
	["taxonomy|t=s", "Taxonomy ID of genome", { "default" => 6666666 }],
	["path|p=s", "Path in workspace to save genome"],
	["name|n=s", "Path in workspace to save genome"],
	["overwrite|o", "Overwrite output objects"],
]);
if (!defined($opt->{path})) {
	$opt->{path} = "/".Bio::P3::Workspace::ScriptHelpers::user()."/genomes/";
}
if (!defined($opt->{name})) {
	$opt->{name} = $ARGV[1];
	$opt->{name} =~ s/\s/_/g;
}
my $contigs = $ARGV[0];
my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$opt->{path}]);
if ($opt->{fromfile}) {
	open (my $fh, "<", $contigs);
	my $data = "";
	while (my $line = <$fh>) {
	    $data .= $line;
	}
	close($fh);
	my $res = Bio::P3::Workspace::ScriptHelpers::wscall("create",{
		objects => [[$paths->[0]."/".$opt->{name}.".contigs","contigs",{},$data]],
		overwrite => $opt->overwrite
	});
	$contigs = $paths->[0]."/".$opt->{name}.".contigs";
} else {
	my $cpaths = Bio::P3::Workspace::ScriptHelpers::process_paths([$contigs]);
	$contigs = $cpaths->[0];
}
print "App url:".Bio::P3::Workspace::ScriptHelpers::appurl()."\n";
my $client = Bio::KBase::AppService::Client->new(Bio::P3::Workspace::ScriptHelpers::appurl(),token => Bio::P3::Workspace::ScriptHelpers::token());
my $task = $client->start_app("GenomeAnnotation",{
	contigs => $contigs,
	scientific_name => $ARGV[1],
	code => $opt->{code},
	domain => $opt->{domain},
	output_path => $paths->[0],
	output_file => $opt->{name}
},$paths->[0]);
while ($task->{status} ne "failed" && $task->{status} ne "completed") {
	sleep(3);
	my $res = $client->query_tasks([$task->{id}]);
	$task = $res->{$task->{id}};
	print $task->{status}."\n";
}
print "Task results:\n";
print join("\t", $task->{id}, $task->{app}, $task->{workspace}, $task->{status}, $task->{submit_time}, $task->{completed_time}), "\n";

