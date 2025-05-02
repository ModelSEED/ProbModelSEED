use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
my $configfile = "/disks/p3dev2/deployment/deployment.cfg";
#Bio::KBase::ObjectAPI::config::adminmode(1);
my $helper = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper->new({
	token => Bio::P3::Workspace::ScriptHelpers::token(),
	username => "chenry",
	method => "ModelReconstruction",
	configfile => $configfile
});

my $parameters = {
	media => "/chenry/public/modelsupport/media/ArgonneLBMedia",
	gapfill => 1,
	predict_essentiality => 1,
	genome => "PATRIC:83333.1",
	output_file => "Test83333.1",
	output_path => "/chenry/public/PATRICModels/"
};

$parameters = Bio::KBase::utilities::args($parameters,[],{
	genome_type => undef,
	shock_id => undef,
	media => undef,
	template_model => "auto",
	fulldb => 0,
	output_path => undef,
	genome => undef,
	output_file => undef,
	gapfill => 1,
	probannogapfill => 0,
	probanno => 0,
	predict_essentiality => 1,
	gapfill_model => 0,#This ensures the KBase function does not run gapfilling internally
	thermodynamic_constraints => 0,
	comprehensive_gapfill => 0,
	custom_bound_list => [],
	media_supplement_list => [],
	expseries => undef,
	expression_condition => undef,
	exp_threshold_percentile => 0.5,
	exp_threshold_margin => 0.1,
	activation_coefficient => 0.5,
	omega => 0,
	objective_fraction => 0.1,
	minimum_target_flux => 0.1,
	number_of_solutions => 1,
	annotation_process => "kmer"});

if (defined($parameters->{use_cplex})) {
	Bio::KBase::utilities::setconf("ModelSEED","use_cplex",$parameters->{use_cplex});
}

#Determining output location
if (!defined($parameters->{output_file})) {
	$parameters->{output_file} = $parameters->{genome};
	$parameters->{output_file} =~ s/.+://;
	$parameters->{output_file} =~ s/.+\///;
}
if (!defined($parameters->{output_path})) {
	if ($parameters->{genome_type} eq  "plant") {
		$parameters->{output_path} = "/".Bio::KBase::utilities::user_id()."/".Bio::KBase::utilities::conf("ProbModelSEED","plantseed_home_dir")."/";
	} else {
		$parameters->{output_path} = "/".Bio::KBase::utilities::user_id()."/".Bio::KBase::utilities::conf("ProbModelSEED","home_dir")."/";
	}
}
if (substr($parameters->{output_path},-1,1) ne "/") {
	$parameters->{output_path} .= "/";
}
my $folder = $parameters->{output_path}."/".$parameters->{output_file};

#Creating model folder and adding meta data
print(Bio::KBase::ObjectAPI::utilities::TOJSON({objects => [[$folder,"modelfolder",{},undef]]}));
Bio::ModelSEED::patricenv::call_ws("create",{objects => [[$folder,"modelfolder",{},undef]]});

#############################################################
#Retrieve metadata once to update throughout process
my $user_metadata = Bio::ModelSEED::patricenv::call_ws("get", { objects => [$folder], metadata_only => 1 })->[0][0][7];
$user_metadata->{status}="constructing";
$user_metadata->{status_timestamp} = Bio::KBase::utilities::timestamp();
Bio::ModelSEED::patricenv::call_ws("update_metadata",{objects => [[$folder,$user_metadata]]});

#############################################################
#Loading genome if a shock ID is provided with a genome ID
if(defined($parameters->{shock_id})) {
	$helper->create_genome_from_shock({
		shock_id => $parameters->{shock_id},
		annotate => 1,
		output_path => $folder,
		genome_type => $parameters->{genome_type},
		genome_id => $parameters->{output_file},
		annotation_process => $parameters->{annotation_process}
	});
	$parameters->{genome} = $folder."/genome";
} elsif ($parameters->{genome} =~ m/RAST:/ || $parameters->{genome} =~ m/PATRIC:/) {
	my $GenomeObj = $helper->get_genome($parameters->{genome});
	Bio::ModelSEED::patricenv::call_ws("create", { objects => [ [$folder."/genome", "genome", {}, $GenomeObj->serializeToDB()] ] });
	$parameters->{genome} = $folder."/genome";
}elsif ( $parameters->{genome_type} eq "plant" && $parameters->{annotation_process} eq "blast" ){
	my $kmers = $parameters->{annotation_process} eq "kmer" ? 1 : 0;
	my $blast = $parameters->{annotation_process} eq "blast" ? 1 : 0;

	my $GenomeObj = $helper->get_object($folder."/genome")->serializeToDB();
	my $MinGenomeObj = $helper->get_object($folder."/.plantseed_data/minimal_genome");
	my $annotation_summary = $helper->annotate_plant_genome({genome => $GenomeObj,
									min_genome => $MinGenomeObj,
									kmers => $kmers,
									blast => $blast,
									model_folder => $folder});

	#Saving genome
	my $genome_meta = Bio::ModelSEED::patricenv::call_ws("get",{ objects => [$folder."/genome"], metadata_only=>1 })->[0][0][7];
	Bio::ModelSEED::patricenv::call_ws("create", { objects => [ [$folder."/genome", "genome", $genome_meta, $GenomeObj] ] });
	Bio::ModelSEED::patricenv::call_ws("create", { objects => [ [$folder."/.plantseed_data/minimal_genome", "unspecified", {}, $MinGenomeObj] ]});

	#Updating status
	my $modelfolder_meta = Bio::ModelSEED::patricenv::call_ws("get",{ objects => [$folder], metadata_only=>1 })->[0][0][7];
	$modelfolder_meta->{status}="complete";
	$modelfolder_meta->{status_timestamp} = Bio::KBase::utilities::timestamp();
	Bio::ModelSEED::patricenv::call_ws("update_metadata",{objects => [[$folder,$modelfolder_meta]]});

	return {fbamodel_ref => $folder};
}
$parameters->{genome} =~ s/\/\//\//g;

#############################################################	
#Set options based on genome_type being of plant
if($parameters->{genome_type} eq "plant"){
	if($parameters->{template_model} eq "auto"){
		$parameters->{template_model} = "/chenry/public/modelsupport/templates/PlantModelTemplate";
	}
	$parameters->{gapfill}=0;
	if($parameters->{genome} !~ m/\//){
		$parameters->{genome} = $parameters->{output_path}.$parameters->{genome};
	}
}

if ($parameters->{template_model} =~ m/\//) {
	($parameters->{template_workspace},$parameters->{template_id}) = $helper->util_parserefs($parameters->{template_model});
} else {
	$parameters->{template_id} = $parameters->{template_model};
}
($parameters->{genome_workspace},$parameters->{genome_id}) = $helper->util_parserefs($parameters->{genome});	
$parameters->{workspace} = $parameters->{output_path};
$parameters->{fbamodel_output_id} = $parameters->{output_file};
delete $parameters->{genome};
delete $parameters->{template_model};
my $datachannel = {};
print Data::Dumper->Dump([$parameters]);
#if($parameters->{genome_type} eq "plant"){
Bio::KBase::ObjectAPI::functions::func_build_metabolic_model($parameters,$datachannel);
#Now compute reaction probabilities if they are needed for gapfilling or probanno model building
if ($parameters->{probanno} == 1 || ($parameters->{gapfill} == 1 && $parameters->{probannogapfill} == 1)) {
	my $genomeref = $folder."/genome";
	my $templateref = $datachannel->{fbamodel}->template()->_reference();
	$templateref =~ s/\|\|$//; # Remove the extraneous || at the end of the reference
	my $rxnprobsref = $folder."/rxnprobs";
	$helper->ComputeReactionProbabilities({
		genome => $genomeref,
		template => $templateref,
		rxnprobs => $rxnprobsref
	});
	$datachannel->{fbamodel}->rxnprobs_ref($rxnprobsref);
}
if ($parameters->{gapfill} == 1) {
	$helper->GapfillModel({
		model => $folder,
		media => $parameters->{media},
		integrate_solution => 1,
		probanno => $parameters->{probanno},
		thermodynamic_constraints => $parameters->{thermodynamic_constraints},
		comprehensive_gapfill => $parameters->{comprehensive_gapfill},
		custom_bound_list => $parameters->{custom_bound_list},
		media_supplement_list => $parameters->{media_supplement_list},
		expseries => $parameters->{expseries},
		expression_condition => $parameters->{expression_condition},
		exp_threshold_percentile => $parameters->{exp_threshold_percentile},
		exp_threshold_margin => $parameters->{exp_threshold_margin},
		activation_coefficient => $parameters->{activation_coefficient},
		omega => $parameters->{omega},
		objective_fraction => $parameters->{objective_fraction},
		minimum_target_flux => $parameters->{minimum_target_flux},
		number_of_solutions => $parameters->{number_of_solutions}
	},$datachannel->{fbamodel});			
}
#} else {
my $input = {
	parameters => $parameters,
	genome => $helper->get_object($folder."/genome")->serializeToDB(),
	media => $helper->get_object($parameters->{media})->serializeToDB()
};

my $json = $datachannel->{fbamodel}->serializeToDB();
Bio::KBase::ObjectAPI::utilities::PRINTFILE(Bio::KBase::utilities::conf("ProbModelSEED","work_dir")+"/output_model.json",[$json]);
Bio::KBase::ObjectAPI::utilities::PRINTFILE(Bio::KBase::utilities::conf("ProbModelSEED","work_dir")+"/input.json",[Bio::KBase::ObjectAPI::utilities::TOJSON($input)]);
my $cmd = Bio::KBase::utilities::conf("ProbModelSEED","bin_directory")."/ModelSEEDpy-ModelReconstruction.pl ".Bio::KBase::utilities::conf("ProbModelSEED","work_dir")."/input.json";
print("Command:",$cmd);
	#system($cmd);
	#$data = Bio::KBase::ObjectAPI::utilities::FROMJSON(Bio::KBase::ObjectAPI::utilities::LOADFILE(Bio::KBase::utilities::conf("ProbModelSEED","work_dir")+"/output.json")[0])
	#$modelobj = $helper->PATRICStore()->process_objec($meta,$data,$options)
	#my $wsmeta = Bio::KBase::ObjectAPI::functions::$handler->util_save_object($modelobj,$output->{new_fbamodel_ref},{type => "KBaseFBA.FBAModel"});
#}
if ($parameters->{predict_essentiality} == 1) {
	$helper->FluxBalanceAnalysis({
		model => $folder,
		media => $parameters->{media},
		simulate_ko => 1
	},$datachannel->{fbamodel});
}