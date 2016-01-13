use strict;
use Data::Dumper;

use Bio::P3::Workspace::ScriptHelpers;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
Bio::KBase::ObjectAPI::config::load_config({
	filename => "/disks/p3dev1/deployment/deployment.cfg",
	service => "ProbModelSEED"
});
Bio::KBase::ObjectAPI::logging::log("App starting! Current configuration parameters loaded:\n".Data::Dumper->Dump([Bio::KBase::ObjectAPI::config::all_params()]));

my $procs = $ARGV[0];
my $index = $ARGV[1];

my $filename = "/homes/chenry/KBaseModelList.txt";
my $kbhash = {};
open(my $fh, "<", $filename);
while (my $line = <$fh>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	$kbhash->{$array->[1]} = 1;
}
close($fh);
$filename = "/disks/p3dev1/fba/successlist.txt";
my $completehash = {};
open(my $fh, "<", $filename);
while (my $line = <$fh>) {
	chomp($line);
	my $array = [split(/:/,$line)];
	$completehash->{$array->[1]} = 1;
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
				configfile => "/disks/p3dev1/deployment/deployment.cfg"
			});
			Bio::KBase::ObjectAPI::config::adminmode(1);
		}
		Bio::KBase::ObjectAPI::config::setowner($modellist->[$i]->{owner});
		eval {
			$helper->app_harness("ImportKBaseModel",{
				kbws => "ModelSEEDModels",
				kbid => $modellist->[$i]->{id},
				output_file => $modellist->[$i]->{id},
				kbuser => "chenry",
				kbpassword => "",
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