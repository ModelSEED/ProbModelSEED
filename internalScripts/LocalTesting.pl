use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl;

my $client = Bio::P3::Workspace::ScriptHelpers::msClient();

Bio::KBase::utilities::read_config({
	service => "ProbModelSEED"
});
Bio::ModelSEED::patricenv::create_context_from_client_config({});
#Bio::KBase::ObjectAPI::config::adminmode(1);

my $impl = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl->new();

my $output = $impl->ModelReconstruction({
    genome_type => "microbial_contigs",
    shock_id => "70083daa-b279-4a97-8693-fdcc87a54375",
    output_file => "1052588.4"
});

#print Data::Dumper->Dump([$output]);

#my $output = $client->list_models({});

print "\n\n\n".Data::Dumper->Dump([$output]);