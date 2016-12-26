use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
my $configfile = "/disks/p3dev2/deployment/deployment.cfg";
#$configfile = "/Users/chenry/code/PATRICClient/config.ini";

Bio::KBase::utilities::read_config({
	filename => $configfile,
	service => "ProbModelSEED"
});
Bio::ModelSEED::patricenv::create_context_from_client_config({});

#my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/Users/chenry/workspace/Patric/Genomes/GenomeList.txt");
my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/homes/chenry/PATRICGenomeList.txt");

my $helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
	method => "FindGeneCluster"
});

for (my $i=0; $i < @{$modellist}; $i++) {
#for (my $i=0; $i < 5; $i++) {
	print "Processing genome ".$i."\n";
	if (!-e "/disks/p3dev2/genomes/".$modellist->[$i].".tsv") {
	#if (!-e "/Users/chenry/workspace/genomes/".$modellist->[$i].".tsv") {
		eval {
			my $genome = $helper->retrieve_PATRIC_genome($modellist->[$i],0,1);
			my $features = $genome->{features};
			open ( my $fh, ">", "/Users/chenry/workspace/genomes/".$modellist->[$i].".tsv");
			print $fh "id\tfunction\tcontig\tstart\tdirection\tstop\type\tfigfam\trefseq\tpgfam\tplfam\tgene\n";
			for (my $j=0; $j < @{$features}; $j++) {
				print $fh $features->[$j]->{id}."\t".$features->[$j]->{function}."\t".$features->[$j]->{location}->[0]->[0]."\t".$features->[$j]->{location}->[0]->[1]."\t".$features->[$j]->{location}->[0]->[2]."\t".$features->[$j]->{location}->[0]->[3]."\t".$features->[$j]->{type};
				if (defined($features->[$j]->{ontology_terms}->{FigFam})) {
					print $fh "\t".join("|",keys(%{$features->[$j]->{ontology_terms}->{FigFam}}));
				} else {
					print $fh "\t";
				}
				if (defined($features->[$j]->{ontology_terms}->{RefSeq})) {
					print $fh "\t".join("|",keys(%{$features->[$j]->{ontology_terms}->{RefSeq}}));
				} else {
					print $fh "\t";
				}
				if (defined($features->[$j]->{ontology_terms}->{PGFam})) {
					print $fh "\t".join("|",keys(%{$features->[$j]->{ontology_terms}->{PGFam}}));
				} else {
					print $fh "\t";
				}
				if (defined($features->[$j]->{ontology_terms}->{PLFam})) {
					print $fh "\t".join("|",keys(%{$features->[$j]->{ontology_terms}->{PLFam}}));
				} else {
					print $fh "\t";
				}
				if (defined($features->[$j]->{ontology_terms}->{GeneName})) {
					print $fh "\t".join("|",keys(%{$features->[$j]->{ontology_terms}->{GeneName}}));
				} else {
					print $fh "\t";
				}
				print $fh "\n";
			}
			close($fh);
		};
	}
}