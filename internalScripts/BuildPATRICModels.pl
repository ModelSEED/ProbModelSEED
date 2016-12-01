use strict;
use Bio::KBase::utilities;
use Bio::ModelSEED::patricenv;

Bio::KBase::utilities::read_config({
	service => "ProbModelSEED"
});
Bio::ModelSEED::patricenv::create_context_from_client_config({});

my $procs = $ARGV[0];
my $index = $ARGV[1];

my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/Users/chenry/workspace/PATRIC_genomes/GenomeList.txt");
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
for (my $i=0; $i < @{$modellist}; $i++) {
	if ($i % $procs  == $index) {
		if (!defined($donehash->{$modellist->[$i]})) {
			if ($count % 100 == 0) {
				$helper = undef;
				$helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
					method => "GapfillModel"
				});
				Bio::KBase::ObjectAPI::config::adminmode(1);
			}
			Bio::KBase::ObjectAPI::config::setowner("chenry");
			my $genome = "PATRIC:".$modellist->[$i];
			eval {
				$helper->app_harness("ModelReconstruction",{
					media => "/chenry/public/modelsupport/media/ArgonneLBMedia",
					gapfill => 1,
					predict_essentiality => 1,
					genome => $genome,
					output_file => $modellist->[$i],
					output_path => "/chenry/public/PATRICModels/"
				});
			};
			if ($@) {
				my $error = $@;
				Bio::KBase::ObjectAPI::logging::log($i.":".$modellist->[$i].":".$error);
			} else {
				Bio::KBase::ObjectAPI::logging::log($i.":".$modellist->[$i].":success");
			}
			$count++;
		}
	}
}