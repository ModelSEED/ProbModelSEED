use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
my $configfile = "/disks/p3dev2/deployment/deployment.cfg";
$configfile = "/Users/chenry/code/PATRICClient/config.ini";

Bio::KBase::utilities::read_config({
	service => "ProbModelSEED",
	filename => $configfile
});
Bio::ModelSEED::patricenv::create_context_from_client_config();

my $helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
#	token => Bio::P3::Workspace::ScriptHelpers::token(),
	username => "chenry",
	method => "ModelReconstruction",
#	configfile => $configfile
});

$helper->app_harness("ModelReconstruction",{
	genome => "RAST:224308.187"
});

$helper->app_harness("ModelReconstruction",{
	genome => "PATRIC:1423.176"
});

$helper->app_harness("ModelReconstruction",{
	shock_id => "3789d338-a3c5-4cdc-81a9-19fb6122fef6",
	genome => "Bacillus_subtilis_168",
	genome_type => "microbial_contigs"
});

$helper->app_harness("ModelReconstruction",{
	shock_id => "e6b2f33d-a53b-4136-8017-a82474f24aba",
	genome => "E_coli_genes",
	genome_type => "microbial_features"
});

$helper->app_harness("ModelReconstruction",{
	shock_id => "32c76212-64be-408b-9db4-6601882252f6",
	genome => "E_coli_proteins",
	genome_type => "microbial_features"
});