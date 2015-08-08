use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <model>",[
	["to", "Get model as typed object"],
	["pretty|p", "Pretty print the model"],
]);
my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$ARGV[0]]);
my $model = $paths->[0];
my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
my $output = $client->get_model({
	model => $model,
	to => $opt->{to}
});
my $JSON = JSON->new->utf8(1);
if ($opt->{pretty} == 1) {
	$JSON->pretty(1);
}
#print $JSON->encode($output);
