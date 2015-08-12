use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <genome>",[
	["nogapfill","No gap fill"],
	["fulldb","Full database model"],
	["media|m=s", "Media formulation"],
	["template|t=s","Template model"],
	["ess","Predict essentiality"],
	["solver|s=s", "Solver for FBA"],
	["path|p=s", "Path in workspace to save model"],
	["name|n=s", "Name to use for model in workspace"],
	["app", "Run as app"],
]);
my $paths = [$ARGV[0]];
if (defined($opt->{path})) {
	$paths->[1] = $opt->{path};
}
if (defined($opt->{media})) {
	$paths->[2] = $opt->{media};
}
if (defined($opt->{template})) {
	$paths->[3] = $opt->{template};
}
$paths = Bio::P3::Workspace::ScriptHelpers::process_paths($paths);
my $input = {
	genome => $paths->[0],
};
if (defined($paths->[1])) {
	$input->{media} = $paths->[1];
}
if (defined($opt->{solver})) {
	$input->{solver} = $opt->{solver};
}
if (defined($opt->{fulldb})) {
	$input->{fulldb} = $opt->{fulldb};
}
if (defined($opt->{ess})) {
	$input->{predict_essentiality} = $opt->{ess};
}
if (defined($opt->{nogapfill})) {
	$input->{gapfill} = 0;
}
if (defined($paths->[2])) {
	$input->{output_path} = $paths->[2];
}
if (defined($paths->[3])) {
	$input->{template_model} = $paths->[3];
}
if (!defined($opt->{name})) {
	$input->{output_file} = $input->{genome};
	$input->{output_file} =~ s/.+\///g;
	$input->{output_file} .= ".model";
} else {
	$input->{output_file} = $opt->{name};
}
my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
my $output = $client->ModelReconstruction($input);
print Data::Dumper->Dump($output)."\n";