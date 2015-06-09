use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;

Bio::P3::Workspace::ScriptHelpers::SetConfig({appurl => "http://p3.theseed.org/services/app_service"});
my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <model>",[
	["media|m", "Media formulation"],
	["probanno","Probabilistic annotation"],
	["solver|s=s", "Solver for FBA"],
	["alpha=s", "Alpha"],
	["omega=s", "Omega"],
	["threshold=s", "Expression threshold"],
	["allreversible|r", "Make all reactions reversible"],
	["allowunbalanced|u", "Allow unbalanced reactions"],
	["intsol", "Integrate solution"],
	["rxnko=s", "; delimited list of reaction KO"],
	["geneko=s", "; delimited list of gene KO"],
	["supplement=s", "; delimited list of supplemental compounds"],
	["source=s", "Source model for gapfilling"],
	["thermo=s", "Thermo constraints (simple,full)"],
	["target=s", "Target reaction", { "default" => "bio1" }],
	["app", "Run as app"],
]);
my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$ARGV[0]]);
my $model = $paths->[0];
my $objective = ["biomassflux",$opt->{target},1];
if ($objective->[1] !~ m/^bio/) {
	if ($objective->[1] =~ m/^cpd/) {
		$objective->[0] = "drainflux",
	} else {
		$objective->[0] = "flux",
	}
}
if (defined($opt->{app}) && $opt->{app} == 1) {
	my $client = Bio::KBase::AppService::Client->new(Bio::P3::Workspace::ScriptHelpers::appurl(),token => Bio::P3::Workspace::ScriptHelpers::token());
	my $task = $client->start_app("GapfillModel",{
		model => $model,
		media => $opt->{media},
		probanno => $opt->{probanno},
		alpha => $opt->{alpha},
		allreversible => $opt->{allreversible},
		allowunbalanced => $opt->{allowunbalanced},
		integrate_solution => $opt->{intsol},
		thermo_const_type => $opt->{thermo},
		media_supplement => [split(/;/,$opt->{supplement})],
		geneko => [split(/;/,$opt->{geneko})],
		rxnko => [split(/;/,$opt->{rxnko})],
		low_expression_theshold => $opt->{threshold},
		high_expression_theshold => $opt->{threshold},
		objective_fraction => 0.001,
		uptake_limit => [],
		custom_bounds => [],
		objective => [$objective],
		target_reactions => [],
		adminmode => $opt->{admin}
	},$paths->[0]);
	while ($task->{status} ne "failed" && $task->{status} ne "completed") {
		my $res = $client->query_tasks([$task->{id}]);
		$task = $res->{$task->{id}};
		sleep(3);
	}
	print "Task results:\n";
	print join("\t", $task->{id}, $task->{app}, $task->{workspace}, $task->{status}, $task->{submit_time}, $task->{completed_time}), "\n";
} else {
	my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
	my $output = $client->GapfillModel({
		model => $model,
		media => $opt->{media},
		probanno => $opt->{probanno},
		alpha => $opt->{alpha},
		allreversible => $opt->{allreversible},
		thermo_const_type => $opt->{thermo},
		media_supplement => [split(/;/,$opt->{supplement})],
		geneko => [split(/;/,$opt->{geneko})],
		rxnko => [split(/;/,$opt->{rxnko})],
		objective_fraction => 0.001,
		uptake_limits => [],
		custom_bounds => [],
		objective => [$objective],
		custom_constraints => [],
		low_expression_theshold => $opt->{threshold},
		high_expression_theshold => $opt->{threshold},
		target_reactions => [],
		completeGapfill => 0,
		solver => $opt->{solver},
		omega => 0,
		allowunbalanced => $opt->{allowunbalanced},
		blacklistedrxns => [],
		gauranteedrxns => [],
		exp_raw_data => {},
		source_model => $opt->{source},
		integrate_solution => $opt->{intsol},
		adminmode => $opt->{admin}
	});
	print Data::Dumper->Dump($output)."\n";
}