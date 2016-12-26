use strict;
use Bio::KBase::ObjectAPI::utilities;
use Bio::KBase::utilities;

#my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/Users/chenry/workspace/Patric/Genomes/GenomeList.txt");
my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/homes/chenry/PATRICGenomeList.txt");

my $functions;
my $function_hash;
for (my $i=0; $i < @{$modellist}; $i++) {
#for (my $i=0; $i < 5; $i++) {
	if (-e "/disks/p3dev2/genomes/".$modellist->[$i].".tsv") {
		my $data = Bio::KBase::ObjectAPI::utilities::LOADFILE("/disks/p3dev2/genomes/".$modellist->[$i].".tsv");
#	if (-e "/Users/chenry/workspace/genomes/".$modellist->[$i].".tsv") {
#		my $data = Bio::KBase::ObjectAPI::utilities::LOADFILE("/Users/chenry/workspace/genomes/".$modellist->[$i].".tsv");
		for (my $j=1; $j < @{$data}; $j++) {
			my $rowarray = [split(/\t/,$data->[$j])];
			my $array = [split(/\#/,$rowarray->[1])];
		  	my $function = shift(@{$array});
			$function =~ s/\s+$//;
			$array = [split(/\s*;\s+|\s+[\@\/]\s+/,$function)];
			for (my $k=0; $k < @{$array}; $k++) {
				my $original_name = $array->[$k];
				my $rolename = lc($array->[$k]);
				$rolename =~ s/[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+//g;
				$rolename =~ s/\s//g;
				$rolename =~ s/\#.*$//g;
				if (!defined($functions->{$rolename})) {
					$functions->{$rolename} = 0;
				}
				$function_hash->{$rolename} = $original_name;
				$functions->{$rolename}++;
			}
		}
	}
}

print "Role\tSearchRole\tCount\n";
foreach my $function (keys(%{$functions})) {
	print $function_hash->{$function}."\t".$function."\t".$functions->{$function}."\n";
}
