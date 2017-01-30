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

my $directory = $ARGV[0];

my $sr_translation;
my $r_translation;
my $genomelist = Bio::KBase::ObjectAPI::utilities::LOADFILE($directory."/PATRICGenomeList.txt");
open(my $fh, "<", $directory."BVitaminRoles.txt");
my $rolehash = {};
my $line = <$fh>;
while ($line = <$fh>) {
	chomp($line);
	my $rolearray = [split(/\t/,$line)];
	if (defined($rolearray->[3])) {
		my $itemarray = [split(/;/,$rolearray->[3])];
		my $rolename = lc($itemarray->[1]);
		$rolename =~ s/[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+//g;
		$rolename =~ s/\s//g;
		$rolename =~ s/\#.*$//g;
		$rolehash->{$rolearray->[1]}->{$rolename} = $itemarray->[1];
	}
}
close($fh);

my $clusters = {};
my $mingenes = 2;
my $minroles = 3;
for (my $i=0; $i < @{$genomelist}; $i++) {
#for (my $i=0; $i < 1; $i++) {
	#print $genomelist->[$i]."\n";
	if (-e "/disks/p3dev2/genomes/".$genomelist->[$i].".tsv") {
		my $genomedata = Bio::KBase::ObjectAPI::utilities::LOADFILE("/disks/p3dev2/genomes/".$genomelist->[$i].".tsv");
		my $header = [split(/\t/,$genomedata->[0])];
		my $genes;
		for (my $j=1; $j < @{$genomedata}; $j++) {
			my $array = [split(/\t/,$genomedata->[$j])];
			my $gene;
			for (my $k=0; $k < @{$header}; $k++) {
				$gene->{$header->[$k]} = $array->[$k];	
				if ($header->[$k] eq "function") {
					my $array = [split(/\#/,$gene->{$header->[$k]})];
			  		my $function = shift(@{$array});
					$function =~ s/\s+$//;
					$array = [split(/\s*;\s+|\s+[\@\/]\s+/,$function)];
					$gene->{$header->[$k]} = $array;
					for (my $m=0; $m < @{$array}; $m++) {
						my $rolename = lc($array->[$m]);
						$rolename =~ s/[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+//g;
						$rolename =~ s/\s//g;
						$rolename =~ s/\#.*$//g;
						$gene->{searchroles}->{$rolename} = 1;
						$sr_translation->{$rolename} = $array->[$m];
						$r_translation->{$array->[$m]} = $rolename;
					}
				}
				$gene->{location} = $gene->{contig}."_";
				if ($gene->{start} < 1000000) {
					$gene->{location} .= "0";
				}
				if ($gene->{start} < 100000) {
					$gene->{location} .= "0";
				}
				if ($gene->{start} < 10000) {
					$gene->{location} .= "0";
				}
				if ($gene->{start} < 1000) {
					$gene->{location} .= "0";
				}
				if ($gene->{start} < 100) {
					$gene->{location} .= "0";
				}
				if ($gene->{start} < 10) {
					$gene->{location} .= "0";
				}
				$gene->{location} .= $gene->{start};
			}
			push(@{$genes},$gene);
		}
		my $sortedgenes = [sort { $b->{location} cmp $a->{location} } @{$genes}];
		my $laststart;
		my $laststop;
		my $lastroles;
		my $lastgenes;
		for (my $j=0; $j < @{$sortedgenes}; $j++) {
			my $newcontig = 0;
			foreach my $bvit (keys(%{$rolehash})) {
				if (!defined($lastroles->{$bvit})) {
					$lastroles->{$bvit} = [];
					$laststart->{$bvit} = undef;
					$laststop->{$bvit} = undef;
					$lastgenes->{$bvit} = [];
				}
				my $foundhash = {}; 
				my $genehash = {};
				my $start = undef;
				my $stop = undef;
				for (my $k=0; $k < 10; $k++) {
					if ($j+$k < @{$sortedgenes}) {
						if ($sortedgenes->[$j+$k]->{contig} ne $sortedgenes->[$j]->{contig}) {
							$newcontig = $j+$k;
							last;	
						} else {
							foreach my $sr (keys(%{$sortedgenes->[$j+$k]->{searchroles}})) {
								if (defined($rolehash->{$bvit}->{$sr})) {
									$genehash->{$sortedgenes->[$j+$k]->{id}} = 1;
									$foundhash->{$sr} = 1;
									if (!defined($start)) {
										$start = $j+$k;
									} else {
										$stop = $j+$k;
									}
								}
							}
						}
					} else {
						last;
					}
				}
				my $rolelist = [sort(keys(%{$foundhash}))];
				#Checking that the last cluster is a subset of the current cluster
				foreach my $lastrole (@{$lastroles->{$bvit}}) {
					if (!defined($foundhash->{$lastrole})) {
						#If the last cluster is NOT a subset of the current cluster, then it should be saved
						if (@{$lastroles->{$bvit}} >= $minroles && @{$lastgenes->{$bvit}} >= $mingenes) {
							my $begin = $laststart->{$bvit}-5;
							my $end = $laststop->{$bvit}+5;
							if ($begin < 0) {
								$begin = 0;
							}
							if ($end >= @{$sortedgenes}) {
								$end = @{$sortedgenes}-1;
							}
							my $finalgenelist = [];
							my $tempgenehash;
							for (my $k=0; $k <= @{$lastgenes->{$bvit}}; $k++) {
								$tempgenehash->{$lastgenes->{$bvit}->[$k]} = 1;
							}
							for (my $k=$begin; $k <= $end; $k++) {
								if ($sortedgenes->[$k]->{contig} eq $sortedgenes->[$laststart->{$bvit}]->{contig} && !defined($tempgenehash->{$sortedgenes->[$k]->{id}})) {
									push(@{$finalgenelist},$sortedgenes->[$k]->{id});
								}	
							}
							my $genecount = @{$lastgenes->{$bvit}};
							my $rolecount = @{$lastroles->{$bvit}};
							$clusters->{$bvit}->{join(";",@{$lastroles->{$bvit}})}->{$genomelist->[$i]}->{join(";",@{$lastgenes->{$bvit}})} = [$sortedgenes->[$laststart->{$bvit}]->{id},$sortedgenes->[$laststop->{$bvit}]->{id},$finalgenelist,@{$lastroles->{$bvit}},@{$lastgenes->{$bvit}},$rolecount,$genecount];
							$lastroles->{$bvit} = [];
							$laststart->{$bvit} = undef;
							$laststop->{$bvit} = undef;
							$lastgenes->{$bvit} = [];
							last;
						}
					}
				}
				#Replacing current best cluster if the new cluster is the same or better
				if (@{$rolelist} >= @{$lastroles->{$bvit}}) {
					$lastroles->{$bvit} = $rolelist;
					$laststart->{$bvit} = $start;
					$laststop->{$bvit} = $stop;
					$lastgenes->{$bvit} = [sort(keys(%{$genehash}))];
				}
			}
			if ($newcontig > 0) {
				$j = $newcontig-1;
			}
		}
		foreach my $bvit (keys(%{$rolehash})) {
			if (defined($lastroles->{$bvit})) {
				if (@{$lastroles->{$bvit}} >= $minroles && @{$lastgenes->{$bvit}} >= $mingenes) {
					my $begin = $laststart->{$bvit}-5;
					my $end = $laststop->{$bvit}+5;
					if ($begin < 0) {
						$begin = 0;
					}
					if ($end >= @{$sortedgenes}) {
						$end = @{$sortedgenes}-1;
					}
					my $finalgenelist = [];
					my $tempgenehash;
					for (my $k=0; $k <= @{$lastgenes->{$bvit}}; $k++) {
						$tempgenehash->{$lastgenes->{$bvit}->[$k]} = 1;
					}
					for (my $k=$begin; $k <= $end; $k++) {
						if ($sortedgenes->[$k]->{contig} eq $sortedgenes->[$laststart->{$bvit}]->{contig} && !defined($tempgenehash->{$sortedgenes->[$k]->{id}})) {
							push(@{$finalgenelist},$sortedgenes->[$k]->{id});
						}	
					}
					my $genecount = @{$lastgenes->{$bvit}};
					my $rolecount = @{$lastroles->{$bvit}};
					$clusters->{$bvit}->{join(";",@{$lastroles->{$bvit}})}->{$genomelist->[$i]}->{join(";",@{$lastgenes->{$bvit}})} = [$sortedgenes->[$laststart->{$bvit}]->{id},$sortedgenes->[$laststop->{$bvit}]->{id},$finalgenelist,$rolecount,$genecount];
				}
			}
		}
	}
}

print "B vitamins\tRole count\tGene count\tCandidate count\tRoles\tGenome\tFunction genes\tStart gene\tStop gene\tFinal gene list\n";
foreach my $bvit (keys(%{$clusters})) {
	foreach my $roles (keys(%{$clusters->{$bvit}})) {
		foreach my $genome (keys(%{$clusters->{$bvit}->{$roles}})) {
			foreach my $genes (keys(%{$clusters->{$bvit}->{$roles}->{$genome}})) {
				my $data = $clusters->{$bvit}->{$roles}->{$genome}->{$genes};
				my $genecount = pop(@{$data});
				my $rolecount = pop(@{$data});
				print $bvit."\t".$rolecount."\t".$genecount."\t".@{$data->[2]}."\t".$roles."\t".$genome."\t".$genes."\t".$data->[0]."\t".$data->[1]."\t".join(";",@{$data->[2]})."\n";
			}
		}
	}
}