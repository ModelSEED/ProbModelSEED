use strict;
use Data::Dumper;
use JSON::XS;
use DBI;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::ObjectAPI::utilities;
use Bio::KBase::ObjectAPI::config;
use Bio::KBase::ObjectAPI::KBaseGenomes::Genome;
use Bio::KBase::ObjectAPI::KBaseFBA::FBAModel;
use Bio::KBase::ObjectAPI::KBaseFBA::FBA;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;

my $configfile = "/disks/p3dev1/deployment/deployment.cfg";
#$configfile = "/Users/chenry/code/PATRICClient/config.ini";

my $outdirectory = $ARGV[0];
my $procs = $ARGV[1];
my $index = $ARGV[2];

if (!defined($procs)) {
	$procs = 1;
}
if (!defined($index)) {
	$index = 0;
}

my $filename = "/homes/chenry/KBaseModelList.txt";
my $kbhash = {};
open(my $fh, "<", $filename);
while (my $line = <$fh>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	$kbhash->{$array->[1]} = 1;
}
close($fh);
$filename = "/homes/chenry/PMSModelList.txt";
my $pmslist = {};
open(my $fh, "<", $filename);
while (my $line = <$fh>) {
	chomp($line);
	my $array = [split(/\s+/,$line)];
	$pmslist->{$array->[1]} = 1;
}
close($fh);
$filename = "/homes/chenry/ModelList.txt";
my $modellist = [];
open(my $fb, "<", $filename);
while (my $line = <$fb>) {
	chomp($line);
	my $array = [split(/\t/,$line)];
	if (defined($kbhash->{$array->[0]}) && !defined($pmslist->{$array->[0]}) && $array->[4] > 0) {
		push(@{$modellist},{
			owner => $array->[2],
			id => $array->[0]
		});
	}
}
close($fb);

my $directionhash = {
	"=>" => ">",
	"<=" => "<",
	"<=>" => "="
};

my $helper;
Bio::KBase::ObjectAPI::config::adminmode(1);

my $rxndb = {};
my $db = DBI->connect("DBI:mysql:ModelDB:bio-app-authdb.mcs.anl.gov:3306","webappuser");
my $select = "SELECT * FROM ModelDB.REACTION;";
my $rxns = $db->selectall_arrayref($select, { Slice => {
	_id => 1,
	abbrev => 1,
	abstractReaction => 1,
	code => 1,
	definition => 1,
	deltaG => 1,
	deltaGErr => 1,
	enzyme => 1,
	equation => 1,
	id => 1,
	name => 1,
	reversibility => 1,
	status => 1,
	structuralCues => 1,
	thermoReversibility => 1,
	transportedAtoms => 1,
} });
for (my $i=0; $i < @{$rxns}; $i++) {
	$rxndb->{$rxns->[$i]->{id}} = $rxns->[$i]
}
my $cpddb = {};
$select = "SELECT * FROM ModelDB.COMPOUND;";
my $cpds = $db->selectall_arrayref($select, { Slice => {
	_id => 1,
	abbrev => 1,
	abstractCompound => 1,
	charge => 1,
	deltaG => 1,
	deltaGErr => 1,
	formula => 1,
	id => 1,
	mass => 1,
	name => 1,
	owner => 1,
	pKa => 1,
	pKb => 1,
	public => 1,
	scope => 1,
	stringcode => 1,
	structuralCues => 1,
} });
for (my $i=0; $i < @{$cpds}; $i++) {
	$cpddb->{$cpds->[$i]->{id}} = $cpds->[$i]
}

print "Model count:".@{$modellist}."\n";
my $count = 0;
for (my $i=0; $i < 3; $i++) {
#for (my $i=0; $i < @{$modellist}; $i++) {
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
		$count++;
		Bio::KBase::ObjectAPI::config::setowner($modellist->[$i]->{owner});
		my $model = $modellist->[$i]->{id};
		my $owner = $modellist->[$i]->{owner};
		print $model."\t".$owner."\n";
		my $modelid = $model;
		$select = "SELECT * FROM ModelDB.MODEL WHERE id = ?";
		my $modeldata = $db->selectall_arrayref($select, { Slice => {
			_id => 1,
			source => 1,
			public => 1,
			status => 1,
			autocompleteDate => 1,
			builtDate => 1,
			spontaneousReactions => 1,
			gapFillReactions => 1,
			associatedGenes => 1,
			genome => 1,
			reactions => 1,
			modificationDate => 1,
			id => 1,
			biologReactions => 1,
			owner => 1,
			autoCompleteMedia => 1,
			transporters => 1,
			version => 1,
			autoCompleteReactions => 1,
			compounds => 1,
			autoCompleteTime => 1,
			message => 1,
			associatedSubsystemGenes => 1,
			autocompleteVersion => 1,
			cellwalltype => 1,
			biomassReaction => 1,
			growth => 1,
			noGrowthCompounds => 1,
			autocompletionDualityGap => 1,
			autocompletionObjective => 1,
			name => 1,
			defaultStudyMedia => 1,
		} }, $model);
		if (!defined($modeldata) || !defined($modeldata->[0]->{id})) {
			next;
		}
		$select = "SELECT * FROM ModelDB.BIOMASS WHERE id = ?";
		my $biodata = $db->selectall_arrayref($select, { Slice => {
			_id => 1,
			name => 1,
			public => 1,
			equation => 1,
			modificationDate => 1,
			creationDate => 1,
			id => 1,
			cofactorPackage => 1,
			lipidPackage => 1,
			cellWallPackage => 1,
			protein => 1,
			DNA => 1,
			RNA => 1,
			lipid => 1,
			cellWall => 1,
			cofactor => 1,
			DNACoef => 1,
			RNACoef => 1,
			proteinCoef => 1,
			lipidCoef => 1,
			cellWallCoef => 1,
			cofactorCoef => 1,
			essentialRxn => 1,
			energy => 1,
			unknownPackage => 1,
			unknownCoef => 1
		} }, $modeldata->[0]->{biomassReaction});
		if (!defined($biodata) || !defined($biodata->[0]->{id})) {
			next;
		}
		my $genomeobj = {
			id => $modeldata->[0]->{genome},
			scientific_name => $modeldata->[0]->{name},
			domain => "Bacteria",
			genetic_code => 11,
			dna_size => 0,
			num_contigs => 0,
			source => "RAST",
			source_id => $modeldata->[0]->{genome},
			md5 => "",
			taxonomy => "unknown",
			gc_content => 0.5,
			complete => 0,
			features => []
		};
		my $select = "SELECT * FROM ModelDB.GENOMESTATS WHERE GENOME = ?";
		my $genomes = $db->selectall_arrayref($select, { Slice => {
			genesInSubsystems => 1,
			owner => 1,
			source => 1,
			genes => 1,
			GENOME => 1,
			name => 1,
			taxonomy => 1,
			gramNegGenes => 1,
			size => 1,
			gramPosGenes => 1,
			public => 1,
			genesWithFunctions => 1,
			class => 1,
			gcContent => 1
		}}, $modeldata->[0]->{genome});
		if (defined($genomes) && !defined($genomes->[0]->{GENOME})) {
			$genomeobj->{gc_content} = $genomes->[0]->{gcContent};
			$genomeobj->{taxonomy} = $genomes->[0]->{taxonomy};
			$genomeobj->{dna_size} = $genomes->[0]->{size};
			$genomeobj->{scientific_name} = $genomes->[0]->{name};
	    }
		my $modelobj = {
			id => $model,
			owner => $owner,
			source => "ModelSEED",
			source_id => $model,
			name => $modeldata->[0]->{name},
			type => "SingleGenomeModel",
			genome_ref => $model."/genome||",
			gapfillings => [{
				id => "gf.0",
				gapfill_id => "gf.0",
				fba_ref => $model."/gapfilling/gf.0||",
				integrated => 1,
				integrated_solution => 0,
				media_ref => "/chenry/public/modelsupport/patric-media/Complete||"
			}],	
			biomasses => [{
				id => "bio1",
				name => "bio1",
				other => 0,
				dna => $biodata->[0]->{DNA},
				rna => $biodata->[0]->{RNA},
				protein => $biodata->[0]->{protein},
				cellwall => $biodata->[0]->{cellWall},
				lipid => $biodata->[0]->{lipid},
				cofactor => $biodata->[0]->{cofactor},
				energy => $biodata->[0]->{energy},
				biomasscompounds => []
			}],
			modelcompartments => [],
			modelcompounds => [],
			modelreactions => []
		};
		my $eqn = $biodata->[0]->{equation};
		my $eqarray = [split(/=/,$eqn)];
		my $cpdhash = {};
		for (my $k=0; $k < 2; $k++) {
			$_ = $eqarray->[$k];
			my @array = /(\(*\d*\.*\d*\)*\s*cpd\d+\[[a-z]\])/g;
		    for (my $j=0; $j < @array; $j++) {
		    	if ($array[$j] =~ m/\(*(\d*\.*\d*)\)*\s*(cpd\d+)\[([a-z])\]/) {
		    		my $coef = $1;
					my $cpd = $2;
					my $comp = $3;
					if (length($coef) == 0) {
						$coef = 1;
					}
					if ($k == 0) {
						$coef = -1*$coef;
					}
					if (!defined($cpdhash->{$cpd."_".$comp."0"})) {
				    	my $charge = 0;
				    	my $formula = "";
				    	my $name = $cpd;
				    	if (defined($cpddb->{$cpd}->{name})) {
				    		$name = $cpddb->{$cpd}->{name};
				    	}
				    	if (defined($cpddb->{$cpd}->{formula})) {
				    		$formula = $cpddb->{$cpd}->{formula};
				    	}
				    	if (defined($cpddb->{$cpd}->{charge})) {
				    		$charge = $cpddb->{$cpd}->{charge};
				    	}
				    	push(@{$modelobj->{modelcompounds}},{
				    		id => $cpd."_".$comp."0",
							compound_ref => "~/template/compounds/id/".$cpd,
							name => $name,
							charge => $charge,
							formula => $formula,
							modelcompartment_ref => "~/modelcompartments/id/".$comp."0"
				    	});
				    }
		    		push(@{$modelobj->{biomasses}->[0]->{biomasscompounds}},{
			    		modelcompound_ref => "~/modelcompounds/id/".$cpd."_".$comp."0",
						coefficient => $coef
			    	});
		    	}
		    }
		}
		if ($modeldata->[0]->{cellwalltype} =~ m/egative/) {
	    	$modelobj->{template_ref} = "/chenry/public/modelsupport/templates/GramNegative.modeltemplate||";
	    } else {
	    	$modelobj->{template_ref} = "/chenry/public/modelsupport/templates/GramPositive.modeltemplate||";
	    }
		my $directory = "/vol/model-dev/MODEL_DEV_DB/Models2/".$owner."/".$model."/0/";
		my $select = "SELECT * FROM ModelDB.REACTION_MODEL WHERE MODEL = ?";
		my $rxns = $db->selectall_arrayref($select, { Slice => {
			directionality => 1,
			compartment => 1,
			REACTION => 1,
			MODEL => 1,
			pegs => 1
		} }, $model);
		my $comphash = {};
		my $cpdhash = {};
		my $fba = {
			id => "gf.0",
			fva => 0,
			fluxMinimization => 0,
			findMinimalMedia => 0,
			allReversible => 0,
			simpleThermoConstraints => 0,
			thermodynamicConstraints => 0,
			noErrorThermodynamicConstraints => 0,
			minimizeErrorThermodynamicConstraints => 0,
			quantitativeOptimization => 0,
			maximizeObjective => 1,
			compoundflux_objterms => {},
	    	reactionflux_objterms => {},
			biomassflux_objterms => {bio1 => 1},
			comboDeletions => 0,
			numberOfSolutions => 1,
			objectiveConstraintFraction => 1,
			defaultMaxFlux => 100,
			defaultMaxDrainFlux => 100,
			defaultMinDrainFlux => -100,
			PROMKappa => 0,
			tintleW => 0,
			tintleKappa => 0,
			ExpressionAlpha => 0,
			ExpressionOmega => 0,
			ExpressionKappa => 0,
			decomposeReversibleFlux => 1,
			decomposeReversibleDrainFlux => 0,
			fluxUseVariables => 1,
			drainfluxUseVariables => 0,
			minimize_reactions => 0,
			fbamodel_ref => "../",
			media_ref => "/chenry/public/modelsupport/patric-media/Complete||",
			geneKO_refs => [],
			reactionKO_refs => [],
			additionalCpd_refs => [],
			uptakeLimits => {},
			minimize_reaction_costs => {},
			parameters => {},
			inputfiles => {},
			FBAConstraints => [],
			FBAReactionBounds => [],
			FBACompoundBounds => [],
			objectiveValue => 0,
			outputfiles => {},
			FBACompoundVariables => [],
			FBAReactionVariables => [],
			FBABiomassVariables => [],
			FBAPromResults => [],
			FBATintleResults => [],
			FBADeletionResults => [],
			FBAMinimalMediaResults => [],
			FBAMetaboliteProductionResults => [],
			FBAMinimalReactionsResults => [],
			QuantitativeOptimizationSolutions => [],
			gapfillingSolutions => [{
				id => "sol.0",
		    	solutionCost => 0,
		    	biomassRemoval_refs => [],
		    	mediaSupplement_refs => [],
		    	koRestore_refs => [],
		    	integrated => 1,
		    	suboptimal => 0,
		    	objective => 0,
		    	gfscore => 0,
		    	actscore => 0,
		    	rejscore => 0,
		    	candscore => 0,
		    	rejectedCandidates => [],
		    	failedReaction_refs => [],
		    	activatedReactions => [],
		    	gapfillingSolutionReactions => []
			}]
		};
		my $addedgf = 0;
		my $reversedgf = 0;
		for (my $i=0; $i < @{$rxns}; $i++) {
			my $rxn = $rxns->[$i];
			if (!defined($comphash->{lc($rxn->{compartment})})) {
				push(@{$modelobj->{modelcompartments}},{
					id => lc($rxn->{compartment})."0",
					compartment_ref => "~/template/compartments/id/".lc($rxn->{compartment}),
					compartmentIndex => 0,
					label => lc($rxn->{compartment})."0",
					pH => 7,
					potential => 0
				});
			}
			if ($rxn->{directionality} eq "<=>") {
				$rxn->{directionality} = "=";
			} elsif ($rxn->{directionality} eq "=>") {
				$rxn->{directionality} = ">";
			} elsif ($rxn->{directionality} eq "<=") {
				$rxn->{directionality} = "<";
			}
			my $rxnname = $rxn->{REACTION};
			if (defined($rxndb->{$rxn->{REACTION}}->{name})) {
				$rxnname = $rxndb->{$rxn->{REACTION}}->{name};
			}
			my $enzyme = "";
			if (defined($rxndb->{$rxn->{REACTION}}->{enzyme})) {
				$enzyme = $rxndb->{$rxn->{REACTION}}->{enzyme};
			}
			
			my $currentrxn = {
				id => $rxn->{REACTION}."_".lc($rxn->{compartment})."0",
				reaction_ref => "~/template/reactions/id/".$rxn->{REACTION}."_".lc($rxn->{compartment}),
				name => $rxnname,
				enzyme => $enzyme,
				aliases => [],
				direction => $rxn->{directionality},
				protons => 0,
				modelcompartment_ref => "~/modelcompartments/id/".lc($rxn->{compartment})."0",
				modelReactionReagents => [],
				modelReactionProteins => []
			};
			$currentrxn->{enzyme} =~ s/^\|//;
			$currentrxn->{enzyme} =~ s/\|$//;
			my $tempenzymearray = [split(/\|/,$currentrxn->{enzyme})];
			$currentrxn->{enzyme} = $tempenzymearray->[0];
			if ($rxn->{directionality} eq "=" && $rxndb->{$rxn->{REACTION}}->{reversibility} eq "=>") {
				$currentrxn->{gapfill_data}->{"gf.0"} = "reversed:<";
				$reversedgf++;
				push(@{$fba->{gapfillingSolutions}->[0]->{gapfillingSolutionReactions}},{
					round => 0,
	    			reaction_ref => "~/fbamodel/template/reactions/id/".$rxn->{REACTION},
	    			compartment_ref => "~/fbamodel/template/compartments/id/c",
	    			direction => "<",
	    			compartmentIndex => 0,
	    			candidateFeature_refs => []
				});
			} elsif ($rxn->{directionality} eq "=" && $rxndb->{$rxn->{REACTION}}->{reversibility} eq "<=") {
				$currentrxn->{gapfill_data}->{"gf.0"} = "reversed:>";
				$reversedgf++;
				push(@{$fba->{gapfillingSolutions}->[0]->{gapfillingSolutionReactions}},{
					round => 0,
	    			reaction_ref => "~/fbamodel/template/reactions/id/".$rxn->{REACTION},
	    			compartment_ref => "~/fbamodel/template/compartments/id/c",
	    			direction => ">",
	    			compartmentIndex => 0,
	    			candidateFeature_refs => []
				});
			}
			push(@{$modelobj->{modelreactions}},$currentrxn);
			my $eqn = $rxndb->{$rxn->{REACTION}}->{equation};
			my $eqarray = [split(/=/,$eqn)];
			for (my $k=0; $k < 2; $k++) {
				$_ = $eqarray->[$k];
				my @array = /(\(*\d*\.*\d*\)*\s*cpd\d+\[*[a-z]*\]*)/g;
			    for (my $j=0; $j < @array; $j++) {
			    	if ($array[$j] =~ m/\(*(\d*\.*\d*)\)*\s*(cpd\d+)\[*([a-z]*)\]*/) {
			    		my $coef = $1;
						my $cpd = $2;
						my $comp = $3;
						if (length($coef) == 0) {
							$coef = 1;
						}
						if (length($comp) == 0) {
							$comp = "c";
						}
						if ($k == 0) {
							$coef = -1*$coef;
						}
						if (!defined($cpdhash->{$cpd."_".$comp."0"})) {
					    	my $charge = 0;
					    	my $formula = "";
					    	my $name = $cpd;
					    	if (defined($cpddb->{$cpd}->{name})) {
					    		$name = $cpddb->{$cpd}->{name};
					    	}
					    	if (defined($cpddb->{$cpd}->{formula})) {
					    		$formula = $cpddb->{$cpd}->{formula};
					    	}
					    	if (defined($cpddb->{$cpd}->{charge})) {
					    		$charge = $cpddb->{$cpd}->{charge};
					    	}
					    	push(@{$modelobj->{modelcompounds}},{
					    		id => $cpd."_".$comp."0",
								compound_ref => "~/template/compounds/id/".$cpd,
								name => $name,
								charge => $charge,
								formula => $formula,
								modelcompartment_ref => "~/modelcompartments/id/".$comp."0"
					    	});
					    }
			    		push(@{$currentrxn->{modelReactionReagents}},{
				    		modelcompound_ref => "~/modelcompounds/id/".$cpd."_".$comp."0",
							coefficient => $coef,
				    	});
			    	}
			    }
			}
			my $gpr = Bio::KBase::ObjectAPI::utilities::translateGPRHash(Bio::KBase::ObjectAPI::utilities::parseGPR($rxn->{pegs}));
			my $unknown = 0;
			my $anygenes = 0;
			for (my $m=0; $m < @{$gpr}; $m++) {
				push(@{$currentrxn->{modelReactionProteins}},{
					complex_ref => "",
					note => "Imported GPR",
					modelReactionProteinSubunits => []
				});
				for (my $j=0; $j < @{$gpr->[$m]}; $j++) {	
					push(@{$currentrxn->{modelReactionProteins}->[$m]->{modelReactionProteinSubunits}},{
						role => "",
						triggering => 0,
						optionalSubunit => 0,
						note => "Imported GPR",
						feature_refs => []
					});
					for (my $k=0; $k < @{$gpr->[$m]->[$j]}; $k++) {
						if ($gpr->[$m]->[$j]->[$k] =~ m/^peg\./) {
							$gpr->[$m]->[$j]->[$k] = "fig|".$genomeobj->{id}.".".$gpr->[$m]->[$j]->[$k];
							push(@{$currentrxn->{modelReactionProteins}->[$m]->{modelReactionProteinSubunits}->[$j]->{feature_refs}},"~/genome/features/id/".$gpr->[$m]->[$j]->[$k]);
							$anygenes = 1;
						} elsif ($gpr->[$m]->[$j]->[$k] =~ m/^fig\|/) {
							push(@{$currentrxn->{modelReactionProteins}->[$m]->{modelReactionProteinSubunits}->[$j]->{feature_refs}},"~/genome/features/id/".$gpr->[$m]->[$j]->[$k]);
							$anygenes = 1;
						} elsif (lc($gpr->[$m]->[$j]->[$k]) eq "unknown") {
							$unknown = 1;
						}
					}
				}
			}
			if ($anygenes == 0 && $unknown == 1) {
				$currentrxn->{gapfill_data}->{"gf.0"} = "added:".$rxn->{directionality};
				push(@{$fba->{gapfillingSolutions}->[0]->{gapfillingSolutionReactions}},{
					round => 0,
	    			reaction_ref => "~/fbamodel/template/reactions/id/".$rxn->{REACTION},
	    			compartment_ref => "~/fbamodel/template/compartments/id/c",
	    			direction => $rxn->{directionality},
	    			compartmentIndex => 0,
	    			candidateFeature_refs => []
				});
				$addedgf++;
			}
		}
		print "Reactions:".@{$modelobj->{modelreactions}}."\n";
		print "Added:".$addedgf."\n";
		print "Reversed:".$reversedgf."\n";
		if (-e $directory."annotations/features.txt") {
			open (my $fh, "<", $directory."annotations/features.txt");
			my @lines = <$fh>;
			close($fh);
			my $headings = [split(/\t/,shift(@lines))];
			my $headinghash = {};
			for (my $i=0; $i < @{$headings};$i++) {
				$headinghash->{$headings->[$i]} = $i;
			}
			for (my $i=0; $i < @lines;$i++) {
				my $line = $lines[$i];
				chomp($line);
				my $row = [split(/\t/,$line)];
				my $length = $row->[$headinghash->{"MAX LOCATION"}] - $row->[$headinghash->{"MIN LOCATION"}];
				push(@{$genomeobj->{features}},{
					id => $row->[$headinghash->{ID}],
					location => [["contig1",$row->[$headinghash->{"MIN LOCATION"}],$row->[$headinghash->{DIRECTION}],$length]],
					type => $row->[$headinghash->{TYPE}],
					function => $row->[$headinghash->{ROLES}]
				});
			}
		}
		$genomeobj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeobj);
		$genomeobj->parent($helper->PATRICStore());
		$modelobj = Bio::KBase::ObjectAPI::KBaseFBA::FBAModel->new($modelobj);
		$modelobj->parent($helper->PATRICStore());
		$modelobj->genome($genomeobj);
		$fba = Bio::KBase::ObjectAPI::KBaseFBA::FBA->new($fba);
		$fba->parent($helper->PATRICStore());
		$modelobj->gapfillings()->[0]->fba($fba);
		$helper->save_object("/".$owner."/modelseed/".$model,$modelobj,"model");
		$helper->save_object("/".$owner."/modelseed/".$model."/gapfilling/gf.0",$fba,"fba");
	}
}
