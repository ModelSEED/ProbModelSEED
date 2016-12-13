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

my $modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/Users/chenry/workspace/Patric/Genomes/GenomeList.txt");
$modellist = Bio::KBase::ObjectAPI::utilities::LOADFILE("/homes/chenry/PATRICGenomeList.txt");

my $helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
	method => "FindGeneCluster"
});

my $blacklist = {
	hypotheticalprotein => 1,
	repeatregion => 1
};

my $funclochash;
my $funccochash;
my $funchash;
my $funcnamehash;

for (my $i=0; $i < @{$modellist}; $i++) {
#for (my $i=0; $i < 20; $i++) {
	print "Processing genome ".$i."\n";
	my $genome = $helper->retrieve_PATRIC_genome($modellist->[$i],0,1);
	my $ftrs = [sort { $b->{start} cmp $a->{start} } @{$genome->{features}}];
	my $rolehash = {};
	for (my $j=0; $j < @{$ftrs}; $j++) {
		my $ftr = $ftrs->[$j];
		my $function = $ftr->{function};
		$ftr->{roles} = {};
	  	my $array = [split(/\#/,$function)];
	  	$function = shift(@{$array});
		$function =~ s/\s+$//;
		$array = [split(/\s*;\s+|\s+[\@\/]\s+/,$function)];
		for (my $k=0; $k < @{$array}; $k++) {
			my $original_name = $array->[$k];
			my $rolename = lc($array->[$k]);
			$rolename =~ s/[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+//g;
			$rolename =~ s/\s//g;
			$rolename =~ s/\#.*$//g;
			if (!defined($blacklist->{$rolename})) {
				$funcnamehash->{$rolename} = $original_name;
				$ftr->{roles}->{$rolename} = 1;
				$rolehash->{$rolename} = 1;
			}
		}
	}
	my $roles = [sort { $b cmp $a } keys(%{$rolehash})];
	for (my $j=0; $j < @{$roles}; $j++) {
		if (!defined($funchash->{$roles->[$j]})) {
			$funchash->{$roles->[$j]} = 0;
		}
		$funchash->{$roles->[$j]}++;
		for (my $k=($j+1); $k < @{$roles}; $k++) {
			if (!defined($funccochash->{$roles->[$j]}->{$roles->[$k]})) {
				$funccochash->{$roles->[$j]}->{$roles->[$k]} = 0;
			}
			$funccochash->{$roles->[$j]}->{$roles->[$k]}++;
		}
	}
	for (my $j=0; $j < @{$ftrs}; $j++) {
		for (my $k=-5; $k <= 5; $k++) {
			if ($k != 0) {
				if (!defined($ftrs->[$j]->{location}) || !defined($ftrs->[$j+$k]->{location}) ||  $ftrs->[$j+$k]->{location}->[0]->[0] eq $ftrs->[$j]->{location}->[0]->[0]) {
					foreach my $role (keys(%{$ftrs->[$j]->{roles}})) {
						foreach my $roletwo (keys(%{$ftrs->[$j+$k]->{roles}})) {
							my $rolelist = [sort { $b cmp $a } ($role,$roletwo)];
							$funclochash->{$rolelist->[0]}->{$rolelist->[1]}->{$modellist->[$i]} = 1;
						}
					}
				}
			}
		}	
	}
}

print "Function1	Function2	Genomes	OccurColocalized	OccurTogether	AGenomes	BGenomes\n";
foreach my $role (keys(%{$funclochash})) {
	if ($funchash->{$role} >= 5) {
		foreach my $roletwo (keys(%{$funclochash->{$role}})) {
			if ($funchash->{$roletwo} >= 5) {
				my $count = keys(%{$funclochash->{$role}->{$roletwo}});
				my $genomes = join(";",keys(%{$funclochash->{$role}->{$roletwo}}));
				print $funcnamehash->{$role}."\t".$funcnamehash->{$roletwo}."\t".$genomes."\t".$count."\t".$funccochash->{$role}->{$roletwo}."\t".$funchash->{$role}."\t".$funchash->{$roletwo}."\n";
			}
		}
	}
}