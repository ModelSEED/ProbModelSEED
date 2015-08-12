use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <model>",[
	["nogenome|n", "Do not copy the genome as well"],
	["plantseed|p", "Copying a PlantSEED model"],
]);
my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$ARGV[0]]);
my $model = $paths->[0];
my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
my $input = {
	model => $model,
	copy_genome => 1,
};
if (defined($opt->{nogenome})) {
	$input->{copy_genome} = 0;
}
if (defined($opt->{plantseed})) {
	$input->{plantseed} = $opt->{plantseed};
}
if (defined($opt->{admin})) {
	$input->{adminmode} = $opt->{admin};
}
my $output = $client->copy_model($input);
my $JSON = JSON->new->utf8(1);
if ($opt->{pretty} == 1) {
	$JSON->pretty(1);
}
print $JSON->encode($output);

