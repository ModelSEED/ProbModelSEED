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

my $filename = "/homes/chenry/PMSModelList.txt";
my $kbhash = {};
open(my $fh, "<", $filename);
while (my $line = <$fh>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	$kbhash->{$array->[1]} = 1;
}
close($fh);
$filename = "/homes/chenry/ModelList.txt";
my $modellist = [];
open(my $fb, "<", $filename);
while (my $line = <$fb>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	if (defined($kbhash->{$array->[0]}) && !defined($completehash->{$array->[0]})) {
		push(@{$modellist},{
			owner => $array->[2],
			id => $array->[0]
		});
	}
}
close($fb);

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
		eval {
			$helper->app_harness("TranslateOlderModels",{
				model => "/chenry/models/".$modellist->[$i]->{id},
				output_path => "/".$modellist->[$i]->{owner}."/modelseed/"
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