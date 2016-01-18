use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
my $configfile = "/disks/p3dev1/deployment/deployment.cfg";
#$configfile = "/Users/chenry/code/PATRICClient/config.ini";

	
Bio::KBase::ObjectAPI::config::load_config({
	filename => $configfile,
	service => "ProbModelSEED"
});
Bio::KBase::ObjectAPI::logging::log("App starting! Current configuration parameters loaded:\n".Data::Dumper->Dump([Bio::KBase::ObjectAPI::config::all_params()]));

my $procs = $ARGV[0];
my $index = $ARGV[1];

my $filename = "/homes/chenry/BuildList.txt";
my $modellist = [];
open(my $fb, "<", $filename);
while (my $line = <$fb>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	push(@{$modellist},{
		owner => $array->[1],
		id => $array->[0],
		genome => $array->[2]
	});
}
close($fb);

$filename = "/homes/chenry/PubSEED.txt";
my $pubseedgenomes = {};
open(my $fa, "<", $filename);
while (my $line = <$fa>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	$pubseedgenomes->{$array->[0]} = $array->[1];
}
close($fa);

my $helper;
Bio::KBase::ObjectAPI::config::adminmode(1);

my $count = 0;
for (my $i=0; $i < @{$modellist}; $i++) {
	if ($i % $procs  == $index) {
		if ($count % 100 == 0) {
			$helper = undef;
			$helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
				token => Bio::P3::Workspace::ScriptHelpers::token(),
				username => "chenry",
				method => "ModelReconstruction",
				configfile => $configfile
			});
			Bio::KBase::ObjectAPI::config::adminmode(1);
		}
		Bio::KBase::ObjectAPI::config::setowner($modellist->[$i]->{owner});
		my $genome = "RAST:".$modellist->[$i]->{genome};
		if (defined($pubseedgenomes->{$modellist->[$i]->{genome}})) {
			$genome = "PUBSEED:".$modellist->[$i]->{genome};
		}
		eval {
			$helper->app_harness("ModelReconstruction",{
				genome => $genome,
				output_file => $modellist->[$i]->{id}
			});
		};
		if ($@) {
			my $error = $@;
			Bio::KBase::ObjectAPI::logging::log($i.":".$modellist->[$i]->{id}.":".$error);
		} else {
			Bio::KBase::ObjectAPI::logging::log($i.":".$modellist->[$i]->{id}.":success");
		}
		$count++;
	}
}