use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <model>",[
	["media|m", "Media formulation"],
	["fva","Flux variability analysis"],
	["ess","Predict essentiality"],
	["minflux","Minimize fluxes"],
	["minmedia","Compute minimal media"],	
	["solver|s=s", "Solver for FBA"],
	["allreversible|r", "Make all reactions reversible"],
	["rxnko=s", "; delimited list of reaction KO"],
	["geneko=s", "; delimited list of gene KO"],
	["supplement=s", "; delimited list of supplemental compounds"],
	["thermo=s", "Thermo constraints (simple,full)"],
	["objective=s", "Objective reaction", { "default" => "bio1" }],
	["app", "Run as app"],
]);
my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$ARGV[0]]);
my $model = $paths->[0];
my $objective = ["biomassflux",$opt->{target},1];
if ($objective->[1] !~ m/^bio/) {
	if ($objective->[1] =~ m/^cpd/) {
		$objective->[0] = "drainflux";
	} else {
		$objective->[0] = "flux";
	}
}
my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
my $output = $client->FluxBalanceAnalysis({
	model => $model,
	media => $opt->{media},
	predict_essentiality => $opt->{ess}
	fva => $opt->{fva},
	minimizeflux => $opt->{minflux},
	findminmedia => $opt->{minmedia},
	thermo_const_type => $opt->{thermo},
	media_supplement => [split(/;/,$opt->{supplement})],
	geneko => [split(/;/,$opt->{geneko})],
	rxnko => [split(/;/,$opt->{rxnko})],
	objective_fraction => 0.001,
	uptake_limits => [],
	custom_bounds => [],
	objective => [$objective],
	custom_constraints => [],
	solver => $opt->{solver},
});
print Data::Dumper->Dump($output)."\n";