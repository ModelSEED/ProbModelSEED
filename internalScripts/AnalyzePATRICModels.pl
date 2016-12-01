use strict;
use Bio::KBase::utilities;
use Bio::ModelSEED::patricenv;
use Bio::KBase::ObjectAPI::utilities;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;

Bio::KBase::utilities::read_config({
	service => "ProbModelSEED"
});
Bio::ModelSEED::patricenv::create_context_from_client_config({});
Bio::KBase::utilities::setconf("ProbModelSEED","run_as_app",0);
Bio::KBase::utilities::setconf("ModelSEED","use_cplex",1);
my $procs = $ARGV[0];
my $index = $ARGV[1];

my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/Users/chenry/workspace/PATRIC/Genomes/GenomeList.txt");
#my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/homes/chenry/PATRICGenomeList.txt");
#my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/homes/chenry/ShortGenomeList.txt");
#my $donelist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/disks/p3dev2/fba/genomesuccess.out");
my $donelist = [];
my $donehash = {};
for (my $i=0; $i < @{$donelist}; $i++) {
	$donelist->[$i] =~ s/:success//;
	$donehash->{$donelist->[$i]} = 1;
}

my $helper;
$helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
	method => "GapfillModel"
});

my $count = 0;
for (my $i=0; $i < 5; $i++) {
#for (my $i=0; $i < @{$modellist}; $i++) {
	if ($i % $procs  == $index) {
		if (!defined($donehash->{$modellist->[$i]})) {
			if ($count % 100 == 0) {
				$helper = undef;
				$helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
					method => "GapfillModel"
				});
			}
			eval {
				$helper->app_harness("GapfillModel",{
					model => "/chenry/public/PATRICModels/".$modellist->[$i],
					media => "/chenry/public/modelsupport/media/ArgonneLBMedia"
				});
				$helper->app_harness("FluxBalanceAnalysis",{
					model => "/chenry/public/PATRICModels/".$modellist->[$i],
					media => "/chenry/public/modelsupport/media/ArgonneLBMedia",
					simulate_ko => 1
				});
			};
			if ($@) {
				my $error = $@;
				Bio::KBase::utilities::log($i.":".$modellist->[$i].":".$error);
			} else {
				Bio::KBase::utilities::log($i.":".$modellist->[$i].":success");
			}
			$count++;
		}
	}
}