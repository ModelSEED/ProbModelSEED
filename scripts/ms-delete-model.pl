use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <model>",[]);
if (!defined($ARGV[0])) {
	print "Must supply model to delete!\n".$usage."\n";
	exit();	
}
my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$ARGV[0]]);
my $model = $paths->[0];
my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
my $output = $client->delete_model({
	model => $model
});
print Data::Dumper->Dump([$output])."\n";