use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <genome>",[
	["plantseed|p", "Copying a PlantSEED genome"],
]);
my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$ARGV[0]]);
my $genome = $paths->[0];
my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
my $input = {
	genome => $genome,
};
if (defined($opt->{plantseed})) {
	$input->{plantseed} = $opt->{plantseed};
}
my $output = $client->copy_genome($input);
my $JSON = JSON->new->utf8(1);
if ($opt->{pretty} == 1) {
	$JSON->pretty(1);
}
print $JSON->encode($output);

