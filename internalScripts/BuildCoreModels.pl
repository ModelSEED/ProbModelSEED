use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
my $configfile = "/disks/p3dev2/deployment/deployment.cfg";
#$configfile = "/Users/chenry/code/PATRICClient/config.ini";
	
Bio::KBase::ObjectAPI::config::load_config({
	filename => $configfile,
	service => "ProbModelSEED"
});
Bio::KBase::ObjectAPI::logging::log("App starting! Current configuration parameters loaded:\n".Data::Dumper->Dump([Bio::KBase::ObjectAPI::config::all_params()]));

my $procs = $ARGV[0];
my $index = $ARGV[1];

#my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/Users/chenry/workspace/PATRIC_genomes/GenomeList.txt");
my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/homes/chenry/PATRICGenomeList.txt");

my $helper;
Bio::KBase::ObjectAPI::config::adminmode(1);

$helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
	token => Bio::P3::Workspace::ScriptHelpers::token(),
	username => "chenry",
	method => "ModelReconstruction",
	configfile => $configfile
});

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
		Bio::KBase::ObjectAPI::config::setowner("chenry");
		my $genome = "REFSEQ:".$modellist->[$i];
		eval {
			$helper->app_harness("ModelReconstruction",{
				template_model => "/chenry/public/modelsupport/templates/Core.modeltemplate",
				gapfill => 0,
				predict_essentiality => 0,
				genome => $genome,
				output_file => "Core".$modellist->[$i],
				output_path => "/chenry/public/PATRICCoreModels/"
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