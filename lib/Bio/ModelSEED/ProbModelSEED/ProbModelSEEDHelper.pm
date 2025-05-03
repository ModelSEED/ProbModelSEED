package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;
use strict;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

use Bio::P3::Workspace::WorkspaceClientExt;
use JSON::XS;
use Data::Dumper;
use Log::Log4perl;
use Bio::KBase::ObjectAPI::utilities;
use Bio::KBase::utilities;
use Bio::ModelSEED::patricenv;
use Bio::KBase::ObjectAPI::PATRICStore;
use Bio::ModelSEED::Client::SAP;
use Bio::KBase::AppService::Client;
use Bio::KBase::ObjectAPI::KBaseStore;
use Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportClient;
use Bio::KBase::ObjectAPI::functions;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient;
use Bio::KBase::GenomeAnnotation::Client;
use MongoDB::Connection;
use MongoDB::Collection;

use Carp; $SIG{__DIE__} = sub { Carp::confess @_ };

our $logger = undef;

my $typetrans = {
	"KBaseFBA.FBA" => "fba",
	"KBaseFBA.FBAComparison" => "fbacomparison",
	"KBaseFBA.FBAModel" => "model",
	"KBasePhenotypes.PhenotypeSimulationSet" => "phenotypeset",
	"KBaseGenomes.Genome" => "genome",
	"KBaseFBA.FBAPathwayAnalysis" => "fpa_path_analysis",
	"KBaseBiochem.Meda" => "media",
	"KBaseFBA.ModelComparison" => "modelcomparison",
};

my $analysis_type = "";

my %genetic_code = (TTT => 'F',  TCT => 'S',  TAT => 'Y',  TGT => 'C',
					TTC => 'F',  TCC => 'S',  TAC => 'Y',  TGC => 'C',
					TTA => 'L',  TCA => 'S',  TAA => '*',  TGA => '*',
					TTG => 'L',  TCG => 'S',  TAG => '*',  TGG => 'W',
					CTT => 'L',  CCT => 'P',  CAT => 'H',  CGT => 'R',
					CTC => 'L',  CCC => 'P',  CAC => 'H',  CGC => 'R',
					CTA => 'L',  CCA => 'P',  CAA => 'Q',  CGA => 'R',
					CTG => 'L',  CCG => 'P',  CAG => 'Q',  CGG => 'R',
					ATT => 'I',  ACT => 'T',  AAT => 'N',  AGT => 'S',
					ATC => 'I',  ACC => 'T',  AAC => 'N',  AGC => 'S',
					ATA => 'I',  ACA => 'T',  AAA => 'K',  AGA => 'R',
					ATG => 'M',  ACG => 'T',  AAG => 'K',  AGG => 'R',
					GTT => 'V',  GCT => 'A',  GAT => 'D',  GGT => 'G',
					GTC => 'V',  GCC => 'A',  GAC => 'D',  GGC => 'G',
					GTA => 'V',  GCA => 'A',  GAA => 'E',  GGA => 'G',
					GTG => 'V',  GCG => 'A',  GAG => 'E',  GGG => 'G');

#****************************************************************************
#Data retrieval and storage functions functions
#****************************************************************************
sub save_object {
	my($self, $ref,$data,$type,$metadata) = @_;
	my $object = $self->PATRICStore()->save_object($data,$ref,$metadata,$type,1);
	return $object;
}
sub copy_object {
	my($self,$ref,$destination,$recursive) = @_;
	return Bio::ModelSEED::patricenv::call_ws("copy",{
		objects => [[$ref,$destination]],
		adminmode => Bio::KBase::utilities::conf("ProbModelSEED","adminmode"),
		overwrite => 1,
		recursive => $recursive,
	});
}
sub get_object {
	my($self, $ref,$type,$options) = @_;
	my $object = $self->PATRICStore()->get_object($ref,$options);
	if (defined($type)) {
		my $objtype = $self->PATRICStore()->get_object_type($ref);
		if ($objtype ne $type) {
			$self->error("Type retrieved (".$objtype.") does not match specified type (".$type.")!");
		}
	}
	return $object;
}

sub get_genome {
	my($self, $ref) = @_;
	my $obj;
	if ($ref =~ m/^PATRIC:(.+)/) {
		return $self->retrieve_PATRIC_genome($1);
	} elsif ($ref =~ m/^PATRICSOLR:(.+)/) {
		Bio::KBase::utilities::setconf("ProbModelSEED","old_models",1);
		return $self->retrieve_PATRIC_genome($1);
	} elsif ($ref =~ m/^REFSEQ:(.+)/) {
		return $self->retrieve_PATRIC_genome($1,1);
	} elsif ($ref =~ m/^PUBSEED:(.+)/) {
		return $self->retrieve_SEED_genome($1);
	} elsif ($ref =~ m/^RAST:(.+)/) {
		return $self->retrieve_RAST_genome($1);
	} else {
		$obj = $self->get_object($ref);
		if (defined($obj) && ref($obj) ne "Bio::KBase::ObjectAPI::KBaseGenomes::Genome" && defined($obj->{output_files})) {
			my $output = $obj->{output_files};
			for (my $i=0; $i < @{$obj->{output_files}}; $i++) {
				if ($obj->{output_files}->[$i]->[0] =~ m/\.genome$/) {
					$ref = $obj->{output_files}->[$i]->[0];
				}
			}
			$obj = $self->get_object($ref,"genome");
		}
	}
	if (!defined($obj)) {
		$self->error("Genome retrieval failed!");
	}
	return $obj;
}
sub get_model_meta {
	my($self, $ref) = @_;
	my $metas = Bio::ModelSEED::patricenv::call_ws("get",{
		objects => [$ref],
		metadata_only => 1,
		adminmode => Bio::KBase::utilities::conf("ProbModelSEED","adminmode")
	});
	if (!defined($metas->[0]->[0]->[0])) {
		return undef;
	}
	return $metas->[0]->[0];
}

sub update_model_meta {
	my($self,$ref,$meta,$create_time) = @_;
	$self->workspace_service()->update_metadata({
		objects => [ [$ref,$meta]],#,"modelfolder",Bio::KBase::utilities::timestamp()] ],
		adminmode => Bio::KBase::utilities::conf("ProbModelSEED","adminmode")
	});
	return;
}
#This function retrieves or sets the biochemistry object in the server memory, making retrieval of biochemsitry very fast
sub biochemistry {
	my($self,$bio) = @_;
	if (defined($bio)) {
		#In this case, the cache is being overwritten with an existing biochemistry object (e.g. ProbModelSEED servers will call this)
		$self->{_cached_biochemistry} = $bio;
		$self->PATRICStore()->cache()->{Bio::KBase::utilities::conf("ProbModelSEED","biochemistry")}->[0] = $bio->wsmeta();
		$self->PATRICStore()->cache()->{Bio::KBase::utilities::conf("ProbModelSEED","biochemistry")}->[1] = $bio;
	}
	if (!defined($self->{_cached_biochemistry})) {
		$self->{_cached_biochemistry} = $self->get_object(Bio::KBase::utilities::conf("ProbModelSEED","biochemistry"),"biochemistry");		
	}
	return $self->{_cached_biochemistry};
}

sub workspace_service {
	my($self) = @_;
	if (!defined($self->{_workspace_service})) {
		$self->{_workspace_service} = Bio::P3::Workspace::WorkspaceClientExt->new(Bio::KBase::utilities::conf("ProbModelSEED","workspace-url"),token => Bio::KBase::utilities::token());
	}
	return $self->{_workspace_service};
}
sub app_service {
	my($self) = @_;
	if (!defined($self->{_app_service})) {
		$self->{_app_service} = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient->new(Bio::KBase::utilities::conf("ProbModelSEED","appservice_url"),token => Bio::KBase::utilities::token());
	}
	return $self->{_app_service};
}
sub PATRICStore {
	my($self) = @_;
	if (!defined($self->{_PATRICStore})) {
		my $cachetarg = {};
		my $catcharray = [split(/;/,Bio::KBase::utilities::conf("ProbModelSEED","cache_targets"))];
		for (my $i=0; $i < @{$catcharray}; $i++) {
			$cachetarg->{$catcharray->[$i]} = 1;
		}
		$self->{_PATRICStore} = Bio::KBase::ObjectAPI::PATRICStore->new({
			helper => $self,
			data_api_url => Bio::KBase::utilities::conf("ProbModelSEED","data_api_url"),
			workspace => $self->workspace_service(),
			adminmode => Bio::KBase::utilities::conf("ProbModelSEED","adminmode"),
			file_cache => Bio::KBase::utilities::conf("ProbModelSEED","file_cache"),
			cache_targets => $cachetarg
		});
	}
	return $self->{_PATRICStore};
}
sub KBaseStore {
	my($self,$parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,[],{
		kbwsurl => Bio::KBase::utilities::conf("ProbModelSEED","kbwsurl"),
		kbuser => undef,
		kbpassword => undef,
		kbtoken => undef
	});
	if (!defined($parameters->{kbtoken})) {
		my $token = Bio::KBase::ObjectAPI::utilities::kblogin({
			user_id => $parameters->{kbuser},
			password => $parameters->{kbpassword}
		});
		if (!defined($token)) {
			Bio::KBase::utilities::error("Failed to authenticate KBase user ".$parameters->{kbuser});
		}
		$parameters->{kbtoken} = $token;
	}
	require "Bio/KBase/workspace/Client.pm";
	my $wsclient = Bio::KBase::workspace::Client->new($parameters->{kbwsurl},token => $parameters->{kbtoken});
	return Bio::KBase::ObjectAPI::KBaseStore->new({
		provenance => [{
			"time" => DateTime->now()->datetime()."+0000",
			service_ver => $VERSION,
			service => "ProbModelSEED",
			method => Bio::KBase::utilities::method(),
			method_params => [],
			input_ws_objects => [],
			resolved_ws_objects => [],
			intermediate_incoming => [],
			intermediate_outgoing => []
		}],
		workspace => $wsclient,
		file_cache => undef,
		cache_targets => [],
	});
}

#****************************************************************************
#Utility functions
#****************************************************************************
sub error {
	my($self,$msg) = @_;
	Bio::KBase::utilities::error($msg);
}

#taken from gjoseqlib
sub read_fasta{
	my $dataR = shift;
	my @seqs = map { $_->[2] =~ tr/ \n\r\t//d; $_ }
	map { /^(\S+)([ \t]+([^\n\r]+)?)?[\n\r]+(.*)$/s ? [ $1, $3 || '', $4 || '' ] : () }
			   split /[\n\r]+>[ \t]*/m, $dataR;

	#  Fix the first sequence, if necessary
	$seqs[0]->[0] =~ s/^>//;  # remove > if present
	return \@seqs;
}

#****************************************************************************
#Research functions
#****************************************************************************
=head3 delete_model

Definition:
	Genome = $self->delete_model(ref Model);
Description:
	Deletes the specified model
		
=cut
sub delete_model {
	my($self,$model) = @_;
	# Not quite sure what will happen if the model or modelfolder does not exist 
	my $output = Bio::ModelSEED::patricenv::call_ws("delete",{
		objects => [$model],
		deleteDirectories => 1,
		force => 1,
	});
	# Only return metadata on model object.
	return $output->[0];
}

=head3 get_model_data

Definition:
	model_data = $self->get_model_data(ref modelref);
Description:
	Gets the specified model
		
=cut
sub get_model_data {
	my ($self,$modelref) = @_;
	my $model = $self->get_object($modelref);
	return $model->export({format => "condensed"});
}

sub get_model_summary {
	my ($self,$model) = @_;
	my $modelmeta = $model->wsmeta();
	my $numcpds = @{$model->modelcompounds()};
	my $numrxns = @{$model->modelreactions()};
	my $numcomps = @{$model->modelcompartments()};
	my $numbio = @{$model->biomasses()};
	my $output = {
		id => $modelmeta->[0],
		source => $model->source(),
		source_id => $modelmeta->[0],
		name => $model->name(),
		type => $model->type(),
		genome_ref => $modelmeta->[2].$modelmeta->[0]."/genome",
		template_ref => $model->template_ref(),
		num_compounds => $numcpds,
		num_reactions => $numrxns,
		num_compartments => $numcomps,
		num_biomasses => $numbio,
		num_genes => $model->gene_count(),
		rundate => $modelmeta->[3],
		"ref" => $modelmeta->[2].$modelmeta->[0],
		gene_associated_reactions => $model->gene_associated_reaction_count(),
		gapfilled_reactions => $model->gapfilled_reaction_count(),
		fba_count => 0,
		num_biomass_compounds => $model->biomass_compound_count(),
		integrated_gapfills => $model->integrated_gapfill_count(),
		unintegrated_gapfills => $model->unintegrated_gapfill_count()
	};
	if (defined($model->genome_ref()) && defined($model->genome())) {
		$output->{genome_source} = $model->genome()->source();
	}
	$output->{template_ref} =~ s/\|\|//;
	my $list = Bio::ModelSEED::patricenv::call_ws("ls",{
		paths => [$modelmeta->[2].$modelmeta->[0]."/fba"],
		excludeDirectories => 1,
		excludeObjects => 0,
		recursive => 0,
		query => {type => "fba"}
	});
	if (defined($list->{$modelmeta->[2].$modelmeta->[0]."/fba"})) {
		$list = $list->{$modelmeta->[2].$modelmeta->[0]."/fba"};
		$output->{fba_count} = @{$list};
	}
	return $output;
}

=head3 classify_genome

Definition:
	Genome = $self->classify_genome(string classifier,Genome genome);
Description:
	Returns the cell wall classification for genome
		
=cut
sub classify_genome {
	my($self,$classifier,$genome) = @_;
	my $data = [split(/\n/,$classifier)];
	my $headings = [split(/\t/,$data->[0])];
	my $popprob = [split(/\t/,$data->[1])];
	my $classdata = {};
	for (my $i=1; $i < @{$headings}; $i++) {
		$classdata->{classifierClassifications}->{$headings->[$i]} = {
			name => $headings->[$i],
			populationProbability => $popprob->[$i]
		};
	}
	my $cfRoleHash = {};
	for (my $i=2;$i < @{$data}; $i++) {
		my $row = [split(/\t/,$data->[$i])];
		my $searchrole = Bio::KBase::ObjectAPI::utilities::convertRoleToSearchRole($row->[0]);
		$classdata->{classifierRoles}->{$searchrole} = {
			classificationProbabilities => {},
			role => $row->[0]
		};
		for (my $j=1; $j < @{$headings}; $j++) {
			$classdata->{classifierRoles}->{$searchrole}->{classificationProbabilities}->{$headings->[$j]} = $row->[$j];
		}
	}
	my $scores = {};
	my $sum = 0;
	foreach my $class (keys(%{$classdata->{classifierClassifications}})) {
		$scores->{$class} = 0;
		$sum += $classdata->{classifierClassifications}->{$class}->{populationProbability};
	}
	my $genes = $genome->features();
	foreach my $gene (@{$genes}) {
		my $roles = $gene->roles();
		foreach my $role (@{$roles}) {
			my $searchrole = Bio::KBase::ObjectAPI::utilities::convertRoleToSearchRole($role);
			if (defined($classdata->{classifierRoles}->{$searchrole})) {
				foreach my $class (keys(%{$classdata->{classifierClassifications}})) {
					$scores->{$class} += $classdata->{classifierRoles}->{$searchrole}->{classificationProbabilities}->{$class};
				}
			}
		}
	}
	my $largest;
	my $largestClass;
	foreach my $class (keys(%{$classdata->{classifierClassifications}})) {
		$scores->{$class} += log($classdata->{classifierClassifications}->{$class}->{populationProbability}/$sum);
		if (!defined($largest)) {
			$largest = $scores->{$class};
			$largestClass = $class;
		} elsif ($largest > $scores->{$class}) {
			$largest = $scores->{$class};
			$largestClass = $class;
		}
	}
	return $largestClass;
}
=head3 retrieve_PATRIC_genome

Definition:
	Genome = $self->retrieve_PATRIC_genome(string genome);
Description:
	Returns typed object for genome in PATRIC reference database
		
=cut
sub retrieve_PATRIC_genome {
	my ($self,$genomeid,$refseq,$hashonly) = @_;
	#Retrieving genome information
	my $data = Bio::KBase::ObjectAPI::utilities::rest_download({url => Bio::KBase::utilities::conf("ProbModelSEED","data_api_url")."genome/?genome_id=".$genomeid."&http_accept=application/json"});
	if (!defined($refseq)) {
		$refseq = 0;
	}
	$data = $data->[0];
	my $perm = "n";
	my $uperm = "o";
	if ($data->{public} == 1) {
		$perm = "r";
		$uperm = "r";
	}
	$data = Bio::KBase::utilities::args($data,[],{
		genome_length => 0,
		contigs => 0,
		genome_name => "Unknown",
		taxon_lineage_names => ["Unknown"],
		owner => "Unknown",
		gc_content => 0,
		publication => "Unknown",
		completion_date => "1970-01-01T00:00:00+0000"
	});
	my $meta = [
		$genomeid,
		"genome",
		Bio::KBase::utilities::conf("ProbModelSEED","data_api_url")."genome/?genome_id=".$genomeid."&http_accept=application/json",
		$data->{completion_date},
		$genomeid,
		$data->{owner},
		$data->{genome_length},
		{},
		{},
		$uperm,
		$perm
	];
	my $genomesource = "PATRIC";
	if ($refseq == 1) {
		$genomesource = "RefSeq";
	}
	my $genome = {
		id => $genomeid,
		scientific_name => $data->{genome_name},
		domain => $data->{taxon_lineage_names}->[0],
		genetic_code => 11,
		dna_size => $data->{genome_length},
		num_contigs => $data->{contigs},
		contigs => [],
		contig_lengths => [],
		contig_ids => [],
		source => $genomesource,
		source_id => $genomeid,
		md5 => "none",
		taxonomy => join(":",@{$data->{taxon_lineage_names}}),
		gc_content => $data->{gc_content},
		complete => 1,
		publications => [$data->{publication}],
		features => [],
		contigset_ref => "",
	};
	#Retrieving feature information
	my $start = 0;
	my $params = {};
	my $loopcount = 0;
	my $ftrcount = 0;
	my $allftrs = [];
	while ($start >= 0 && $loopcount < 100) {
		$loopcount++;#Insurance that no matter what, this loop won't run for more than 100 iterations
		my $ftrdata = Bio::KBase::ObjectAPI::utilities::rest_download({url => Bio::KBase::utilities::conf("ProbModelSEED","data_api_url")."genome_feature/?genome_id=".$genomeid."&http_accept=application/json&limit(10000,$start)"},$params);
		if (defined($ftrdata) && @{$ftrdata} > 0) {
			push(@{$allftrs},@{$ftrdata});
		}
		my $currentcount = @{$ftrdata};
		$ftrcount += $currentcount;
		if ($ftrcount < $params->{count}) {
			$start = $ftrcount;
		} else {
			$start = -1;
		}
	}
	my $patricids = {};
	my $refseqids = {};
	my $stops = {};
	for (my $i=0; $i < @{$allftrs}; $i++) {
		my $ftrdata = $allftrs->[$i];
		if ($ftrdata->{feature_type} ne "pseudogene") {
			if ($ftrdata->{strand} eq "-" && $ftrdata->{annotation} eq "RefSeq") {
				$stops->{$ftrdata->{start}} = $ftrdata;
			} elsif ($ftrdata->{annotation} eq "RefSeq") {
				$stops->{$ftrdata->{end}} = $ftrdata;
			}
		}
	}
	my $refseqgenes = 0;
	my $patricgenes = 0;
	my $match = 0;
	my $weakermatch = 0;
	my $unsortedftrlist = [];
	for (my $i=0; $i < @{$allftrs}; $i++) {
		my $ftrdata = $allftrs->[$i];
		if ($ftrdata->{annotation} eq "PATRIC") {
			push(@{$unsortedftrlist},$ftrdata);
			$patricgenes++;
			if ($ftrdata->{strand} eq "-" && defined($stops->{$ftrdata->{start}}) && $ftrdata->{strand} eq $stops->{$ftrdata->{start}}->{strand}){
				$match++;
				$ftrdata->{refseqgene} = $stops->{$ftrdata->{start}};
				if (defined($stops->{$ftrdata->{start}}->{patricgene})) {
					delete($stops->{$ftrdata->{start}}->{refseqgene});
					$weakermatch--;
				}
				$stops->{$ftrdata->{start}}->{patricgene} = $ftrdata->{feature_id};
			} elsif ($ftrdata->{strand} eq "+" && defined($stops->{$ftrdata->{end}}) && $ftrdata->{strand} eq $stops->{$ftrdata->{end}}->{strand}){
				$match++;
				$ftrdata->{refseqgene} = $stops->{$ftrdata->{end}};
				if (defined($stops->{$ftrdata->{end}}->{patricgene})) {
					delete($stops->{$ftrdata->{end}}->{refseqgene});
					$weakermatch--;
				}
				$stops->{$ftrdata->{end}}->{patricgene} = $ftrdata->{feature_id};
#			} elsif ($ftrdata->{strand} eq "+") {
#				for (my $j=0; $j < 100; $j++) {
#					my $startindex = ($ftrdata->{end} - 50 + $j);
#					if (defined($stops->{$startindex}) && !defined($stops->{$startindex}->{patricgene}) && $ftrdata->{strand} eq $stops->{$startindex}->{strand} && abs($ftrdata->{start}-$stops->{$startindex}->{start}) < 50) {
#						$weakermatch++;
#						$ftrdata->{refseqgene} = $stops->{$startindex};
#						$stops->{$startindex}->{patricgene} = $ftrdata->{feature_id};
#						last;
#					}
#				}
#			} elsif ($ftrdata->{strand} eq "-") {
#				for (my $j=0; $j < 100; $j++) {
#					my $startindex = ($ftrdata->{start} - 50 + $j);
#					if (defined($stops->{$startindex}) && !defined($stops->{$startindex}->{patricgene}) && $ftrdata->{strand} eq $stops->{$startindex}->{strand} && abs($ftrdata->{end}-$stops->{$startindex}->{end}) < 50) {
#						$weakermatch++;
#						$ftrdata->{refseqgene} = $stops->{$startindex};
#						$stops->{$startindex}->{patricgene} = $ftrdata->{feature_id};
#						last;
#					}
#				}
			}
		} else {
			$refseqgenes++;
			$refseqids->{$ftrdata->{feature_id}} = $ftrdata;
		}
	}
	my $sortedftrlist = [sort { $b->{start} cmp $a->{start} } @{$unsortedftrlist}];
	my $funchash = Bio::KBase::ObjectAPI::utilities::get_SSO();
	for (my $i=0; $i < @{$sortedftrlist}; $i++) {
		my $id;
		my $data = $sortedftrlist->[$i];
		if ($refseq == 1 && defined($data->{refseqgene}->{refseq_locus_tag})) {
			$id = $data->{refseqgene}->{refseq_locus_tag}; 
		} else {
			$id = $data->{patric_id};
		}
		if (defined($id)) {		
			my $ftrobj = {id => $id,type => "CDS",aliases=>[]};		
			if (defined($data->{start})) {
				$ftrobj->{location} = [[$data->{sequence_id},$data->{start},$data->{strand},$data->{na_length}]];
			}
			if (defined($data->{feature_type})) {
				$ftrobj->{type} = $data->{feature_type};
			}
			if (defined($data->{product})) {
				$ftrobj->{function} = $data->{product};
			}
			if (defined($data->{na_sequence})) {
				$ftrobj->{dna_sequence} = $data->{na_sequence};
				$ftrobj->{dna_sequence_length} = $data->{na_length};
			}
			if (defined($data->{aa_sequence})) {
				$ftrobj->{protein_translation} = $data->{aa_sequence};
				$ftrobj->{protein_translation_length} = $data->{aa_length};
				$ftrobj->{md5} = $data->{aa_sequence_md5};
			}
			if (defined($data->{refseqgene}->{refseq_locus_tag})) {
				$ftrobj->{ontology_terms}->{RefSeq}->{$data->{refseqgene}->{refseq_locus_tag}} = {
					id => $data->{refseqgene}->{refseq_locus_tag},
					term_name => $data->{refseqgene}->{product}
				};
				if (defined($data->{refseqgene}->{gene})) {
					$ftrobj->{ontology_terms}->{GeneName}->{$data->{refseqgene}->{gene}} = {
						id => $data->{refseqgene}->{gene}
					};
				}
			}
			if (defined($data->{patric_id})) {
				$ftrobj->{ontology_terms}->{PATRIC}->{$data->{patric_id}} = {
					id => $data->{patric_id}
				};
			}
			if (defined($data->{figfam_id})) {
				$ftrobj->{ontology_terms}->{FigFam}->{$data->{figfam_id}} = {
					id => $data->{figfam_id}
				};
			}
			if (defined($data->{pgfam_id})) {
				$ftrobj->{ontology_terms}->{PGFam}->{$data->{pgfam_id}} = {
					id => $data->{pgfam_id}
				};
			}
			if (defined($data->{plfam_id})) {
				$ftrobj->{ontology_terms}->{PLFam}->{$data->{plfam_id}} = {
					id => $data->{plfam_id}
				};
			}
			if (defined($data->{accession})) {
				$ftrobj->{ontology_terms}->{Accession}->{$data->{accession}} = {
					id => $data->{accession}
				};
			}
			if (defined($data->{product})) {
				my $function = $data->{product};
	  			my $array = [split(/\#/,$function)];
	  			$function = shift(@{$array});
				$function =~ s/\s+$//;
				$array = [split(/\s*;\s+|\s+[\@\/]\s+/,$function)];
				for (my $k=0; $k < @{$array}; $k++) {
					my $rolename = lc($array->[$k]);
					$rolename =~ s/[\d\-]+\.[\d\-]+\.[\d\-]+\.[\d\-]+//g;
					$rolename =~ s/\s//g;
					$rolename =~ s/\#.*$//g;
					if (defined($funchash->{$rolename})) {
						$ftrobj->{ontology_terms}->{SSO}->{$funchash->{$rolename}->{id}} = {
							id => $funchash->{$rolename}->{id},
							term_name => $funchash->{$rolename}->{name}
						};
					}
				}
			}
			if (defined($data->{go})) {
				for (my $k=0; $k < @{$data->{go}}; $k++) {
					my $array = [split(/\|/,$data->{go}->[$k])];
					$ftrobj->{ontology_terms}->{GO}->{$array->[0]} = {
						id => $array->[0],
						term_name => $array->[1]
					};
				}
			}
			push(@{$genome->{features}},$ftrobj);
		}
	}
	if ($hashonly == 1) {
		return $genome;
	}
	$genome = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genome);
	$genome->wsmeta($meta);
	if ($refseq == 1) {
		$genome->_reference("REFSEQ:".$genomeid);
		$self->PATRICStore()->cache()->{"REFSEQ:".$genomeid} = [$meta,$genome];
	} else {
		$genome->_reference("PATRIC:".$genomeid);
		$self->PATRICStore()->cache()->{"PATRIC:".$genomeid} = [$meta,$genome];
	}
	$genome->parent($self->PATRICStore());
	return $genome;
}
=head3 retrieve_SEED_genome
Definition:
	Genome = $self->retrieve_SEED_genome(string genome);
Description:
	Returns typed object for genome in SEED reference database
		
=cut
sub retrieve_SEED_genome {
	my($self,$id) = @_;
	my $sapsvr = Bio::ModelSEED::Client::SAP->new();
	my $data = $sapsvr->genome_data({
		-ids => [$id],
		-data => [qw(gc-content dna-size name taxonomy domain genetic-code)]
	});
	if (!defined($data->{$id})) {
		$self->error("PubSEED genome ".$id." not found!");
	}
	my $genomeObj = {
		id => $id,
		scientific_name => $data->{$id}->[2],
		domain => $data->{$id}->[4],
		genetic_code => $data->{$id}->[5],
		dna_size => $data->{$id}->[1],
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "PubSEED",
		source_id => $id,
		taxonomy => $data->{$id}->[3],
		gc_content => $data->{$id}->[0]/100,
		complete => 1,
		publications => [],
		features => [],
	};
	my $contigset = {
		name => $genomeObj->{scientific_name},
		source_id => $genomeObj->{source_id},
		source => $genomeObj->{source},
		type => "Organism",
		contigs => []
	};
	my $featureHash = $sapsvr->all_features({-ids => $id});
	my $genomeHash = $sapsvr->genome_contigs({
		-ids => [$id]
	});
	my $featureList = $featureHash->{$id};
	my $contigList = $genomeHash->{$id};
	my $functions = $sapsvr->ids_to_functions({-ids => $featureList});
	my $locations = $sapsvr->fid_locations({-ids => $featureList});
	my $sequences = $sapsvr->fids_to_proteins({-ids => $featureList,-sequence => 1});
	my $contigHash = $sapsvr->contig_sequences({
		-ids => $contigList
	});
	foreach my $key (keys(%{$contigHash})) {
		$genomeObj->{num_contigs}++;
		push(@{$genomeObj->{contig_ids}},$key);
		push(@{$genomeObj->{contig_lengths}},length($contigHash->{$key}));
		push(@{$contigset->{contigs}},{
			id => $key,
			"length" => length($contigHash->{$key}),
			md5 => Digest::MD5::md5_hex($contigHash->{$key}),
			sequence => $contigHash->{$key},
			name => $key
		});
	}
	my $sortedcontigs = [sort { $a->{sequence} cmp $b->{sequence} } @{$contigset->{contigs}}];
	my $str = "";
	for (my $i=0; $i < @{$sortedcontigs}; $i++) {
		if (length($str) > 0) {
			$str .= ";";
		}
		$str .= $sortedcontigs->[$i]->{sequence};	
	}
	$genomeObj->{md5} = Digest::MD5::md5_hex($str);
	$contigset->{md5} = $genomeObj->{md5};
	$contigset->{id} = $id.".contigs";
	for (my $i=0; $i < @{$featureList}; $i++) {
		my $feature = {
  			id => $featureList->[$i],
			type => "peg",
			publications => [],
			subsystems => [],
			protein_families => [],
			aliases => [],
			annotations => [],
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => []
  		};
  		if ($featureList->[$i] =~ m/\.([^\.]+)\.\d+$/) {
  			$feature->{type} = $1;
  		}
		if (defined($functions->{$featureList->[$i]})) {
			$feature->{function} = $functions->{$featureList->[$i]};
		}
		if (defined($sequences->{$featureList->[$i]})) {
			$feature->{protein_translation} = $sequences->{$featureList->[$i]};
			$feature->{protein_translation_length} = length($feature->{protein_translation});
  			$feature->{dna_sequence_length} = 3*$feature->{protein_translation_length};
  			$feature->{md5} = Digest::MD5::md5_hex($feature->{protein_translation});
		}
  		if (defined($locations->{$featureList->[$i]}->[0])) {
			for (my $j=0; $j < @{$locations->{$featureList->[$i]}}; $j++) {
				my $loc = $locations->{$featureList->[$i]}->[$j];
				if ($loc =~ m/^(.+)_(\d+)([\+\-])(\d+)$/) {
					my $array = [split(/:/,$1)];
					if ($3 eq "-" || $3 eq "+") {
						$feature->{location}->[$j] = [$array->[1],$2,$3,$4];
					} elsif ($2 > $4) {
						$feature->{location}->[$j] = [$array->[1],$2,"-",($2-$4)];
					} else {
						$feature->{location}->[$j] = [$array->[1],$2,"+",($4-$2)];
					}
					$feature->{location}->[$j]->[1] = $feature->{location}->[$j]->[1]+0;
					$feature->{location}->[$j]->[3] = $feature->{location}->[$j]->[3]+0;
				}
			}
			
		}
  		push(@{$genomeObj->{features}},$feature);	
	}
	my $meta = [
		$id,
		"genome",
		"PUBSEED:".$id,
		"",
		$id,
		"PubSEED",
		0,
		{},
		{},
		"",
		""
	];
	my $ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($contigset);
	$genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	$genomeObj->contigs($ContigObj);
	$genomeObj->wsmeta($meta);
	$genomeObj->_reference("PUBSEED:".$id);
	$self->PATRICStore()->cache()->{"PUBSEED:".$id} = [$meta,$genomeObj];
	$genomeObj->parent($self->PATRICStore());
	return $genomeObj;
}
=head3 retrieve_RAST_genome

Definition:
	Genome = $self->retrieve_RAST_genome(string genome);
Description:
	Returns typed object for genome in RAST reference database
		
=cut
sub retrieve_RAST_genome {
	my($self,$id,$username,$password) = @_;
	my $mssvr = Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportClient->new(Bio::KBase::utilities::conf("ProbModelSEED","mssserver-url"));
	$mssvr->{token} = Bio::KBase::utilities::token();
	$mssvr->{client}->{token} = Bio::KBase::utilities::token();
	my $data = $mssvr->getRastGenomeData({
		genome => $id,
		username => $username,
		password => $password,
		getSequences => 1,
		getDNASequence => 1
	});
	if (!defined($data->{owner})) {
		$self->_error("RAST genome ".$id." not found!",'get_genomeobject');
	}
	my $genomeObj = {
		id => $id,
		scientific_name => $data->{name},
		domain => $data->{taxonomy},
		genetic_code => 11,
		dna_size => $data->{size},
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => [],
		source => "RAST",
		source_id => $id,
		taxonomy => $data->{taxonomy},
		gc_content => 0.5,
		complete => 1,
		publications => [],
		features => [],
	};
	my $contigset = {
		name => $genomeObj->{scientific_name},
		source_id => $genomeObj->{source_id},
		source => $genomeObj->{source},
		type => "Organism",
		contigs => []
	};
	my $contighash = {};
	for (my $i=0; $i < @{$data->{features}}; $i++) {
		my $ftr = $data->{features}->[$i];
		my $feature = {
  			id => $ftr->{ID}->[0],
			type => "peg",
			publications => [],
			subsystems => [],
			protein_families => [],
			aliases => [],
			annotations => [],
			subsystem_data => [],
			regulon_data => [],
			atomic_regulons => [],
			coexpressed_fids => [],
			co_occurring_fids => [],
			protein_translation_length => 0,
			protein_translation => "",
			dna_sequence_length => 0,
			md5 => ""
  		};
  		if ($ftr->{ID}->[0] =~ m/\.([^\.]+)\.\d+$/) {
  			$feature->{type} = $1;
  		}
  		if (defined($ftr->{SEQUENCE})) {
			$feature->{protein_translation} = $ftr->{SEQUENCE}->[0];
			$feature->{protein_translation_length} = length($feature->{protein_translation});
  			$feature->{dna_sequence_length} = 3*$feature->{protein_translation_length};
  			$feature->{md5} = Digest::MD5::md5_hex($feature->{protein_translation});
		}
		if (defined($ftr->{ROLES})) {
			$feature->{function} = join(" / ",@{$ftr->{ROLES}});
		}
  		if (defined($ftr->{LOCATION}->[0]) && $ftr->{LOCATION}->[0] =~ m/^(.+)_(\d+)([\+\-_])(\d+)$/) {
			my $contigData = $1;
			if (!defined($contighash->{$contigData})) {
				$contighash->{$contigData} = $2;
			} elsif ($2 > $contighash->{$contigData}) {
				$contighash->{$contigData} = $2;
			}
			if ($3 eq "-" || $3 eq "+") {
				$feature->{location} = [[$contigData,$2,$3,$4]];
			} elsif ($2 > $4) {
				$feature->{location} = [[$contigData,$2,"-",($2-$4)]];
			} else {
				$feature->{location} = [[$contigData,$2,"+",($4-$2)]];
			}
			$feature->{location}->[0]->[1] = $feature->{location}->[0]->[1]+0;
			$feature->{location}->[0]->[3] = $feature->{location}->[0]->[3]+0;
		}
  		push(@{$genomeObj->{features}},$feature);
	}
	my $ContigObj;
	if (defined($data->{DNAsequence}->[0])) {
		my $gccount = 0;
		my $size = 0;
		for (my $i=0; $i < @{$data->{DNAsequence}}; $i++) {
			my $closest;
			foreach my $key (keys(%{$contighash})) {
				my $dist = abs(length($data->{DNAsequence}->[$i]) - $contighash->{$key});
				my $closestdist = abs(length($data->{DNAsequence}->[$i]) - $contighash->{$closest});
				if (!defined($closest) || $dist < $closestdist) {
					$closest = $key;
				}
			}
			push(@{$contigset->{contigs}},{
				id => $closest,
				"length" => length($data->{DNAsequence}->[$i]),
				md5 => Digest::MD5::md5_hex($data->{DNAsequence}->[$i]),
				sequence => $data->{DNAsequence}->[$i],
				name => $closest
			});
			push(@{$genomeObj->{contig_lengths}},length($data->{DNAsequence}->[$i]));
			$size += length($data->{DNAsequence}->[$i]);
			push(@{$genomeObj->{contig_ids}},$closest);
			for ( my $j = 0 ; $j < length($data->{DNAsequence}->[$i]) ; $j++ ) {
				if ( substr( $data->{DNAsequence}->[$i], $j, 1 ) =~ m/[gcGC]/ ) {
					$gccount++;
				}
			}
		}
		if ($size > 0) {
			$genomeObj->{gc_content} = $$gccount/$size;
		}
		my $sortedcontigs = [sort { $a->{sequence} cmp $b->{sequence} } @{$contigset->{contigs}}];
		my $str = "";
		for (my $i=0; $i < @{$sortedcontigs}; $i++) {
			if (length($str) > 0) {
				$str .= ";";
			}
			$str .= $sortedcontigs->[$i]->{sequence};	
		}
		$genomeObj->{md5} = Digest::MD5::md5_hex($str);
		$contigset->{md5} = $genomeObj->{md5};
		$contigset->{id} = $id.".contigs";
		$ContigObj = Bio::KBase::ObjectAPI::KBaseGenomes::ContigSet->new($contigset);
	}
	$genomeObj = Bio::KBase::ObjectAPI::KBaseGenomes::Genome->new($genomeObj);
	$genomeObj->contigs($ContigObj);
	my $meta = [
		$id,
		"genome",
		"RAST:".$id,
		"",
		$id,
		$username,
		0,
		{},
		{},
		"",
		""
	];
	$genomeObj->wsmeta($meta);
	$genomeObj->_reference("RAST:".$id);
	$genomeObj->parent($self->PATRICStore());
	$self->PATRICStore()->cache()->{"RAST:".$id} = [$meta,$genomeObj];
	return $genomeObj;
}
=head3 build_fba_object

Definition:
	Genome = $self->build_fba_object({} params);
Description:
	Returns typed object for FBA
		
=cut
sub build_fba_object {
	my($self,$model,$params) = @_;
	my $media = $self->get_object($params->{media},"media");
	if (!defined($media)) {
		$self->error("Media retrieval failed!");
	}
	my $simptherm = 0;
	my $thermconst = 0;
	if ($params->{thermo_const_type} eq "Simple") {
		$simptherm = 1;
		$thermconst = 1;
	}
	my $fba = Bio::KBase::ObjectAPI::KBaseFBA::FBA->new({
		id => $params->{output_file},
		fva => $params->{fva},
		fluxMinimization => $params->{minimizeflux},
		findMinimalMedia => $params->{findminmedia},
		allReversible => $params->{allreversible},
		simpleThermoConstraints => $simptherm,
		thermodynamicConstraints => $thermconst,
		noErrorThermodynamicConstraints => 0,
		minimizeErrorThermodynamicConstraints => 1,
		maximizeObjective => 1,
		compoundflux_objterms => {},
		reactionflux_objterms => {},
		biomassflux_objterms => {},
		comboDeletions => 0,
		numberOfSolutions => 1,
		objectiveConstraintFraction => $params->{objective_fraction},
		defaultMaxFlux => 1000,
		defaultMaxDrainFlux => 0,
		defaultMinDrainFlux => -1000,
		decomposeReversibleFlux => 0,
		decomposeReversibleDrainFlux => 0,
		fluxUseVariables => 0,
		drainfluxUseVariables => 0,
		fbamodel_ref => $model->_reference(),
		media_ref => $media->_reference(),
		geneKO_refs => [],
		reactionKO_refs => [],
		additionalCpd_refs => [],
		uptakeLimits => {},
		parameters => {},
		inputfiles => {},
		FBAConstraints => [],
		FBAReactionBounds => [],
		FBACompoundBounds => [],
		outputfiles => {},
		FBACompoundVariables => [],
		FBAReactionVariables => [],
		FBABiomassVariables => [],
		FBAPromResults => [],
		FBADeletionResults => [],
		FBAMinimalMediaResults => [],
		FBAMetaboliteProductionResults => [],
	});
	if ($params->{predict_essentiality} == 1) {
		$fba->{comboDeletions} = 1;
	}
	$fba->parent($self->PATRICStore());
	foreach my $term (@{$params->{objective}}) {
		if ($term->[0] eq "flux" || $term->[0] eq "reactionflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForReaction($term->[1]);
			if (!defined($obj)) {
				$self->error("Reaction ".$term->[1]." not found!");
			}
			$fba->reactionflux_objterms()->{$obj->id()} = $term->[2];
		} elsif ($term->[0] eq "compoundflux" || $term->[0] eq "drainflux") {
			$term->[0] = "drainflux";
			my $obj = $model->searchForCompound($term->[1]);
			if (!defined($obj)) {
				$self->error("Compound ".$term->[1]." not found!");
			}
			$fba->compoundflux_objterms()->{$obj->id()} = $term->[2];
		} elsif ($term->[0] eq "biomassflux") {
			my $obj = $model->searchForBiomass($term->[1]);
			if (!defined($obj)) {
				$self->error("Biomass ".$term->[1]." not found!");
			}
			$fba->biomassflux_objterms()->{$obj->id()} = $term->[2];
		} else {
			$self->error("Objective variable type ".$term->[0]." not recognized!");
		}
	}
	foreach my $term (@{$params->{custom_bounds}}) {
		if ($term->[0] eq "flux" || $term->[0] eq "reactionflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForReaction($term->[1]);
			if (!defined($obj)) {
				$self->error("Reaction ".$term->[1]." not found!");
			}
			$fba->add("FBAReactionBounds",{modelreaction_ref => $obj->_reference(),variableType=> $term->[0],upperBound => $term->[2],lowerBound => $term->[3]});
		} elsif ($term->[0] eq "compoundflux" || $term->[0] eq "drainflux") {
			$term->[0] = "flux";
			my $obj = $model->searchForCompound($term->[1]);
			if (!defined($obj)) {
				$self->error("Compound ".$term->[1]." not found!");
			}
			$fba->add("FBACompoundBounds",{modelcompound_ref => $obj->_reference(),variableType=> $term->[0],upperBound => $term->[2],lowerBound => $term->[3]});
		} else {
			$self->error("Objective variable type ".$term->[0]." not recognized!");
		}
	}
	if (defined($model->genome_ref())) {
		my $genome = $model->genome();
		foreach my $gene (@{$params->{geneko}}) {
			my $geneObj = $genome->searchForFeature($gene);
			if (defined($geneObj)) {
				$fba->addLinkArrayItem("geneKOs",$geneObj);
			}
		}
	}
	foreach my $reaction (@{$params->{rxnko}}) {
		my $rxnObj = $model->searchForReaction($reaction);
		if (defined($rxnObj)) {
			$fba->addLinkArrayItem("reactionKOs",$rxnObj);
		}
	}
	foreach my $compound (@{$params->{media_supplement}}) {
		my $cpdObj = $model->searchForCompound($compound);
		if (defined($cpdObj)) {
			$fba->addLinkArrayItem("additionalCpds",$cpdObj);
		}
	}
	if ($params->{probanno}) {
		Bio::KBase::utilities::log("Getting reaction likelihoods from ".$model->rxnprobs_ref());
		my $rxnprobs = $self->get_object($model->rxnprobs_ref(),undef,{refreshcache => 1});
		if (!defined($rxnprobs)) {
			$self->error("Reaction likelihood retrieval from ".$model->rxnprobs_ref()." failed");
		}		
		$fba->{parameters}->{"Objective coefficient file"} = "ProbModelReactionCoefficients.txt";
		$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"} = [];
		my $rxncosts = {};
		foreach my $rxn (@{$rxnprobs->{reaction_probabilities}}) {
			$rxncosts->{$rxn->[0]} = (1-$rxn->[1]); # ID is first element, likelihood is second element
		}
		my $compindecies = {};
		my $comps = $model->modelcompartments();
		for (my $i=0; $i < @{$comps}; $i++) {
			$compindecies->{$comps->[$i]->compartmentIndex()}->{$comps->[$i]->compartment()->id()} = 1;
		}
		foreach my $compindex (keys(%{$compindecies})) {
			my $tmp = $model->template();
			my $tmprxns = $tmp->reactions();
			for (my $i=0; $i < @{$tmprxns}; $i++) {
				my $tmprxn = $tmprxns->[$i];
				my $tmpid = $tmprxn->id().$compindex;
				if (defined($rxncosts->{$tmprxn->id()})) {
					push(@{$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"}},"forward\t".$tmpid."\t".$rxncosts->{$tmprxn->id()});
					push(@{$fba->{inputfiles}->{"ProbModelReactionCoefficients.txt"}},"reverse\t".$tmpid."\t".$rxncosts->{$tmprxn->id()});
				}
			}
		}	
		Bio::KBase::utilities::log("Added reaction coefficients from reaction likelihoods in ".$model->rxnprobs_ref());
	}
	return $fba;
}
#****************************************************************************
#Probanno functions
#****************************************************************************


#****************************************************************************
#Non-APP API Call Implementations
#****************************************************************************
sub copy_genome {
	my($self,$input) = @_;
	$input = Bio::KBase::utilities::args($input,["genome"],{
		destination => undef,
		destname => undef,
		to_kbase => 0,
		workspace_url => undef,
		kbase_username => undef,
		kbase_password => undef,
		kbase_token => undef,
		plantseed => 0,
	});
	my $genome = $self->get_genome($input->{genome});
	if (!defined($input->{destination})) {
		$input->{destination} = "/".Bio::KBase::utilities::user_id()."/modelseed/genomes/";
		if ($input->{plantseed} == 1) {
			$input->{destination} = "/".Bio::KBase::utilities::user_id()."/plantseed/genomes/";
		}
	}
	if (!defined($input->{destname})) {
		$input->{destname} = $genome->wsmeta()->[0];
	}
	if ($input->{destination}.$input->{destname} eq $input->{genome}) {
		$self->error("Copy source and destination identical! Aborting!");
	}
	print "Saving genome: ".$input->{destination}.$input->{destname}." from ".$input->{genome}."\n";
	return $self->save_object($input->{destination}.$input->{destname},$genome,"genome");
}

sub copy_model {
	my($self,$input) = @_;
	$input = Bio::KBase::utilities::args($input,["source_model_path"],{
		dest_model_path => undef,
		plantseed => 0
	});

	if(!$input->{destmodel}){
		my $path = "/".Bio::KBase::utilities::user_id()."/modelseed/";
		if ($input->{plantseed} == 1) {
		$path = "/".Bio::KBase::utilities::user_id()."/plantseed/";
		}
		
		my @temp=split(/\//,$input->{source_model_path});
		my $model = $temp[$#temp];
		
		$input->{dest_model_path}=$path.$model;
	}
	
	#Save object as modelfolder
	Bio::ModelSEED::patricenv::call_ws("create", { objects => [ [$input->{dest_model_path},"modelfolder",{},{}] ], overwrite=>1});
	Bio::ModelSEED::patricenv::call_ws("copy", { objects => [ [$input->{source_model_path},$input->{dest_model_path}] ], overwrite=>1, recursive=>1 });							 
	#Copy user meta
	my $UserMeta = Bio::ModelSEED::patricenv::call_ws("get",{ objects => [$input->{source_model_path}], metadata_only=>1 })->[0][0][7];
	Bio::ModelSEED::patricenv::call_ws("update_metadata",{ objects => [[$input->{dest_model_path},$UserMeta]] });

	return $UserMeta;
}

sub plant_pipeline {
	my($self,$input)=@_;

	if(exists($input->{shock_id})){
	$self->create_genome_from_shock($input);
	}

	#Run annotation
	if(exists($input->{annotate}) && $input->{annotate}==1){
	#Add parameters for annotation
	my $AP_input = {};
	$AP_input->{model_folder} = $input->{model_folder};
	$AP_input->{kmers}=1;
	$AP_input->{blast}=0;
	$self->annotate_plant_genome($AP_input);
	}

	#Reform parameters for reconstruction
	my $MR_input = {};
	$MR_input->{genome_type}="plant";
	$MR_input->{gapfill}=0;
	$MR_input->{output_file}=$input->{destname};
	$MR_input->{genome}="/".Bio::KBase::utilities::user_id()."/plantseed/".$input->{destname}."/genome";
	$self->ModelReconstruction($MR_input);

	return "Complete";
}

sub create_genome_from_shock {
	my($self,$args)=@_;
	#Validating arguments
	$args = Bio::KBase::utilities::args($args,["output_path","shock_id","genome_id","genome_type"],{
		annotate => 1,
		scientific_name => "undefined sample",
		taxonomy => "unknown",
		genetic_code => 11,
		annotation_process => "kmer"
	});
	Bio::ModelSEED::patricenv::call_ws("update_metadata",{objects => [[$args->{output_path},{
		status => "annotating",
		status_timestamp => Bio::KBase::utilities::timestamp(),
	}]]});
	
	#Reteiving genome from shock
	my $ua = LWP::UserAgent->new();
	my $shock_url = Bio::KBase::utilities::conf("ProbModelSEED","shock-url")."/node/".$args->{shock_id}."?download";
	my $token = Bio::KBase::utilities::token();
	my $res = $ua->get($shock_url,Authorization => "OAuth " . $token);
	my $raw_data = $res->{_content};

	#This works with data that is both gzipped or plain
	use IO::Uncompress::Gunzip qw(gunzip);
	my $data=undef;
	gunzip \$raw_data => \$data;
	my $seqs = read_fasta($data);
	
	#Building genome
	my $genometype = "Bacteria";
	my $source = "RAST";
	if ($args->{genome_type} eq "plant") {
		$genometype = "Plant";
		$source = "PlantSEED"
	}
	my $GenomeObj = {
		id=>$args->{scientific_name},
		source=>$source,
		scientific_name=>$args->{genome_id},
		taxonomy=>$args->{taxonomy},
		genetic_code=>$args->{genetic_code},
		domain=>$genometype,
		features=>[],
		num_contigs => 0,
		contig_lengths => [],
		contig_ids => []
	};
	my $MinGenomeObj = {
		source => $source,
		scientific_name => $args->{scientific_name},
		similarities_index => {},
		features => [],
		exemplars => {},
		id => $args->{genome_id},
		taxonomy => $args->{taxonomy}
	};
	my $user_meta = { "is_folder"=>0, "taxonomy"=>$args->{taxonomy}, "scientific_name"=>$args->{scientific_name}, "domain"=>$genometype,
			  "num_contigs"=>0,"gc_content"=>0.5,"dna_size"=>0,"num_features"=>0,"genome_id"=>$args->{genome_id},"shock_id"=>$args->{shock_id} };
	
	#Processing features
	if ($args->{genome_type} eq "plant" || $args->{genome_type} eq "microbial_features") {
		my $IsDNA = $self->is_dna($seqs->[0][2]);
		foreach my $ftr (@{$seqs}) {
			my $featureObj = {
				id=>$ftr->[0],
				type => 'CDS',
				function=>""
			};
			my $minftrObj = {
				id=>$ftr->[0],
				subsystems=>[],
				function=>""
			};
			if ($IsDNA == 0) {
				$featureObj->{protein_translation}=$ftr->[2];
				$featureObj->{protein_translation_length}=length($ftr->[2]);
				$featureObj->{dna_sequence_length}=3*length($ftr->[2]);
				$featureObj->{md5}=Digest::MD5::md5_hex($ftr->[2]);
			} else {
				$featureObj->{dna_sequence}=$ftr->[2];
				$featureObj->{dna_sequence_length}=length($ftr->[2]);
				$featureObj->{protein_translation} = $self->translate_nucleotides($ftr->[2]);
				$featureObj->{protein_translation_length} = length($featureObj->{protein_translation});
			}
			$user_meta->{dna_size}+=$featureObj->{dna_sequence_length};
			$user_meta->{num_features}++;
			push(@{$GenomeObj->{features}},$featureObj);
			push(@{$MinGenomeObj->{features}},$minftrObj);
		}
		#Annotating
		if ($args->{annotate} == 1) {
			if ($args->{genome_type} eq "plant") {
				my $kmers = $args->{annotation_process} eq "kmer" ? 1 : 0;
				my $blast = $args->{annotation_process} eq "blast" ? 1 : 0;
				my $annotation_summary = $self->annotate_plant_genome({
					genome => $GenomeObj,
					min_genome => $MinGenomeObj,
					kmers => $kmers,
					blast => $blast,
					model_folder => $args->{output_path}
				});
			} else {
				$GenomeObj = $self->annotate_microbial_genome({
					genome => $GenomeObj
				});
			}
		}
	} else {
	#Processing contigs
		$GenomeObj->{contigs} = [];
		$GenomeObj->{dna_size} = 0;
		foreach my $ftr (@{$seqs}) {
			$GenomeObj->{dna_size} += length($ftr->[2]);
			push(@{$GenomeObj->{contigs}},{
				id => $ftr->[0], dna => $ftr->[2]
			});
			push(@{$GenomeObj->{contig_lengths}},length($ftr->[2]));
			$GenomeObj->{num_contigs}++;
		}
		$GenomeObj = $self->annotate_microbial_contigs({
			genome => $GenomeObj
		});
		$user_meta->{dna_size} = $GenomeObj->{dna_size};
		for (my $i=0; $i < @{$GenomeObj->{features}}; $i++) {
			$user_meta->{num_features}++;
			push(@{$MinGenomeObj->{features}},{
				id => $GenomeObj->{features}->[$i]->{id},
				subsystems=>[],
				function => $GenomeObj->{features}->[$i]->{function}
			});
		}
	}

	#Saving genome
	Bio::ModelSEED::patricenv::call_ws("create", { objects => [ [$args->{output_path}."/genome", "genome", $user_meta, $GenomeObj] ] });
	Bio::ModelSEED::patricenv::call_ws("create", { objects => [ [$args->{output_path}."/.plantseed_data/minimal_genome", "unspecified", {}, $MinGenomeObj] ]});
	return $args->{output_path}."/genome";
}

sub is_dna{
	my ($self,$seq)=@_;

	my $IsDNA=0;
	my %Letters = ();
	foreach my $letter ( map { lc($_) } split(//,$seq) ){
	$Letters{$letter}++;
	}
	my $Sum = $Letters{'a'}+$Letters{'g'}+$Letters{'c'}+$Letters{'t'}+$Letters{'u'};

	if ( $Sum / length($seq) > 0.75 ){
	return 1;
	}else{
	return 0;
	}
}

sub create_featurevalues_from_shock {
	my($self,$input)=@_;
	
	my $ua = LWP::UserAgent->new();
	my $shock_url = Bio::KBase::utilities::conf("ProbModelSEED","shock-url")."/node/".$input->{shock_id}."?download";
	my $token = Bio::KBase::utilities::token();
	my $res = $ua->get($shock_url,Authorization => "OAuth " . $token);
	my $raw_data = $res->{_content};

	#This works with data that is both gzipped or plain
	use IO::Uncompress::Gunzip qw(gunzip);
	my $data=undef;
	gunzip \$raw_data => \$data;

	my %FloatMatrix2D = ( "row_ids" => [], "col_ids" => [], "values" => [] );
	my @Experiments = ();
	my @temp=();
	foreach my $line (split(/\r\n?|\n/,$data)){
		@temp=split(/\t/,$line);
		
		#Header line should contain experiment names
		if(scalar(@Experiments)==0){
		shift(@temp);
		@Experiments=@temp;
		$FloatMatrix2D{"col_ids"}=\@Experiments;
		next;
		}

		my $Gene = shift(@temp);
		push(@{$FloatMatrix2D{"row_ids"}},$Gene);
		push(@{$FloatMatrix2D{"values"}},\@temp);
	}

	my %ExpressionMatrix = ( "type" => "level", "scale" => "log2",
				 "feature_mapping" => {}, "genome_ref" => "",
				 "data" => \%FloatMatrix2D );

	my $user_meta = { "is_folder"=>0, "model_id"=>$input->{destmodel},"shock_id"=>$input->{shock_id} };
	
	my $modelfolder = "/".Bio::KBase::utilities::user_id()."/plantseed/".$input->{destmodel};
	my $expressionfolder = $modelfolder."/.expression_data/";
	Bio::ModelSEED::patricenv::call_ws("create", {objects => [ [$expressionfolder.$input->{destname}, "unspecified", $user_meta, \%ExpressionMatrix] ], overwrite=>1});

	#Update metadata of modelfolder
	my $UserMeta = Bio::ModelSEED::patricenv::call_ws("get",{ objects => [$modelfolder], metadata_only=>1 })->[0][0][7];
	if(!$UserMeta){
		$UserMeta = {};
	}
	if(!exists($UserMeta->{'expression_data'})){
		$UserMeta->{'expression_data'}={};
	}
	$UserMeta->{'expression_data'}{$input->{destname}}=\@Experiments;
	Bio::ModelSEED::patricenv::call_ws("update_metadata",{ objects => [[$modelfolder,$UserMeta]] });

	return $expressionfolder.$input->{destname};
}

sub annotate_plant_genome_wrapper {
	my ($self,$args) = @_;
	$args = Bio::KBase::utilities::args($args,["destmodel"],{kmers => 0,blast => 1});
		
	my $kmers = $args->{kmers};
	my $blast = $args->{blast};
	my $user = Bio::KBase::utilities::user_id();
	my $folder = "/".$user."/".Bio::KBase::utilities::conf("ProbModelSEED","plantseed_home_dir")."/".$args->{destmodel}."/";

	my $GenomeObj = $self->get_object($folder."/genome")->serializeToDB();
	my $MinGenomeObj = $self->get_object($folder."/.plantseed_data/minimal_genome");
	my $output = $self->annotate_plant_genome({genome => $GenomeObj,
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

	return $output;
}

sub annotate_plant_genome {
	my ($self,$args) = @_;
	$args = Bio::KBase::utilities::args($args,["genome","min_genome","model_folder"],{kmers => 1,blast => 0});

	my $modelfolder = $args->{model_folder};
	my $Genome = $args->{genome};
	my $Min_Genome = $args->{min_genome};
	my $genome_user_metadata = {};

	#Updating status
	my $user_metadata = Bio::ModelSEED::patricenv::call_ws("get",{ objects => [$modelfolder], metadata_only=>1 })->[0][0][7];
	$user_metadata->{status}="annotating";
	$user_metadata->{status_timestamp} = Bio::KBase::utilities::timestamp();
	Bio::ModelSEED::patricenv::call_ws("update_metadata",{objects => [[$modelfolder,$user_metadata]]});

	#Translate nucleotides
	foreach my $ftr (@{$Genome->{features}}){
	if($ftr->{dna_sequence}){
		$ftr->{protein_translation} = $self->translate_nucleotides($ftr->{dna_sequence});
		$ftr->{protein_translation_length} = length($ftr->{protein_translation});
		$ftr->{md5} = Digest::MD5::md5_hex($ftr->{protein_translation});
	}
	}
			 
	#Retrieve subsystems
	my $output = Bio::ModelSEED::patricenv::call_ws("get", { objects => ["/plantseed/Data/annotation_overview"] })->[0];
	my $Annotation = Bio::KBase::ObjectAPI::utilities::FROMJSON($output->[1]);
	my %Roles_Subsystems=();
	foreach my $role (@{$Annotation}){
	foreach my $ss (keys %{$role->{subsystems}}){
		$Roles_Subsystems{$role->{role}}{$ss}=1;
	}
	}
	
	my $return_object = {destmodel=>$modelfolder,kmers=>"Not attempted",blast=>"Not attempted"};
	if(exists($args->{kmers}) && $args->{kmers}==1){
	$return_object->{kmers}="Attempted";
	my $hits = $self->annotate_plant_genome_kmers($Genome);
	foreach my $ftr (@{$Genome->{features}}){
		if(exists($hits->{$ftr->{id}})){
		$ftr->{function} = join(" / ",sort keys %{$hits->{$ftr->{id}}});
		}
	}
	
	foreach my $ftr (@{$Min_Genome->{features}}){
		my %SSs = ();
		if(exists($hits->{$ftr->{id}})){
		$ftr->{function} = join(" / ",sort keys %{$hits->{$ftr->{id}}});
		foreach my $role (split(/\s*;\s+|\s+[\@\/]\s+/,$ftr->{function})){
			foreach my $ss (keys %{$Roles_Subsystems{$role}}){
			$SSs{$ss}=1;
			}
		}
		}
		$ftr->{subsystems}=[sort keys %SSs];
	}
	
	$genome_user_metadata->{hit_proteins}=scalar(keys %$hits);
	$return_object->{kmers}=scalar(keys %$hits)." kmer hits";	
	}
	
	if(exists($args->{blast}) && $args->{blast}==1){
	$return_object->{blast}="Attempted";
	my $blast_results = $self->annotate_plant_genome_blast($Genome);
	
	$Min_Genome->{similarities_index}=$blast_results->{index};
	$Min_Genome->{exemplars}=$blast_results->{exems};
	
	for(my $i=0;$i<scalar(@{$blast_results->{sims}});$i++){
		Bio::ModelSEED::patricenv::call_ws("create",{ objects => [[$modelfolder."/.plantseed_data/Sims_".$i,"unspecified",{},
									   $blast_results->{sims}->[$i]]], overwrite=>1 });
	}
	
	$genome_user_metadata->{hit_sims}=$blast_results->{hits};
	$return_object->{blast}=$blast_results->{hits};
	}
	
	my $return_string = join("\n", map { $_.":".$return_object->{$_} } sort keys %$return_object)."\n";
	return $return_string;
}

sub assign_taxonomy_from_close_genome {
	my ($self,$args) = @_;
	$args = Bio::KBase::utilities::args($args,["genome"],{});
	my $genome = $args->{genome};
	if (defined($genome->{close_genomes}->[0]) && $genome->{close_genomes}->[0]->{genome_name} =~ m/(\w+)\s/) {
		$genome->{scientific_name} = $1;
		my $taxid = $genome->{close_genomes}->[0]->{genome_id};
		$taxid =~ s/\.\d+//;
		my $content = Bio::KBase::ObjectAPI::utilities::rest_download({
			json => 0,
			url => "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=taxonomy&id=".$taxid
		});
		if ($content =~ m/\<Lineage\>(.+)\<\/Lineage\>/) {
			$genome->{taxonomy} = $1;
		}
	}
}

sub annotate_microbial_genome {
	my ($self,$args) = @_;
	$args = Bio::KBase::utilities::args($args,["genome"],{});
	my $genome = $args->{genome};	
	my $client = Bio::KBase::GenomeAnnotation::Client->new();
	my $newgenome = $client->create_genome({
		scientific_name => $genome->{scientific_name},
		domain => $genome->{domain},
		genetic_code => $genome->{genetic_code},
		taxonomy => $genome->{taxonomy}
	});
	$genome->{id} = $newgenome->{id};
	$genome->{source} = "RAST";
	$genome->{source_id} = $newgenome->{id};
	$genome = $client->run_pipeline($genome,{stages => Bio::KBase::constants::gene_annotation_pipeline()});
	delete $genome->{analysis_events};
	for(my $i=0; $i < @{$genome->{features}}; $i++) {
		delete $genome->{features}->[$i]->{annotations};
		delete $genome->{features}->[$i]->{feature_creation_event};
		delete $genome->{features}->[$i]->{quality};
		if (defined($genome->{features}->[$i]->{protein_translation})) {
			$genome->{features}->[$i]->{protein_translation_length} = length($genome->{features}->[$i]->{protein_translation});
			$genome->{features}->[$i]->{md5} = Digest::MD5::md5_hex($genome->{features}->[$i]->{protein_translation});
		}
	}
	$self->assign_taxonomy_from_close_genome({genome => $genome});
	return $genome;
}

sub annotate_microbial_contigs {
	my ($self,$args) = @_;
	$args = Bio::KBase::utilities::args($args,["genome"],{});
	my $genome = $args->{genome};
	my $client = Bio::KBase::GenomeAnnotation::Client->new();
	my $newgenome = $client->create_genome({
		scientific_name => $genome->{scientific_name},
		domain => $genome->{domain},
		genetic_code => $genome->{genetic_code},
		taxonomy => $genome->{taxonomy}
	});
	$genome->{id} = $newgenome->{id};
	$genome->{source} = "RAST";
	$genome->{source_id} = $newgenome->{id};
	$genome = $client->run_pipeline($genome,{stages => Bio::KBase::constants::contig_annotation_pipeline()});
	my $ftrhash;
	delete $genome->{analysis_events};
	for(my $i=0; $i < @{$genome->{features}}; $i++) {
		$ftrhash->{$genome->{features}->[$i]->{id}} = $genome->{features}->[$i];
		delete $genome->{features}->[$i]->{annotations};
		delete $genome->{features}->[$i]->{feature_creation_event};
		delete $genome->{features}->[$i]->{quality};
		if (defined($genome->{features}->[$i]->{protein_translation})) {
			$genome->{features}->[$i]->{protein_translation_length} = length($genome->{features}->[$i]->{protein_translation});
			$genome->{features}->[$i]->{md5} = Digest::MD5::md5_hex($genome->{features}->[$i]->{protein_translation});
		}
	}
	my $dna = $client->export_genome($genome,"feature_dna",[]);
	my $array = [split(/\n/,$dna)];
	my $currentgene;
	for (my $i=0; $i < @{$array}; $i++) {
		my $line = $array->[$i];
		if ($line =~ m/\>([^\s^\t]+)/) {
			$currentgene = $1;
			if (defined($ftrhash->{$currentgene})) {
				$ftrhash->{$currentgene}->{dna_sequence} = "";  
			}
		} else {
			$ftrhash->{$currentgene}->{dna_sequence} .= $line;
			$ftrhash->{$currentgene}->{dna_sequence_length} = length($ftrhash->{$currentgene}->{dna_sequence});
		}
	}
	$self->assign_taxonomy_from_close_genome({genome => $genome});
	return $genome;
}

#This function could probably do better if we use BioPerl, I am borrowing code from:
#http://cpansearch.perl.org/src/CJFIELDS/BioPerl-1.6.924/Bio/Tools/CodonTable.pm
#because I didn't want to create a dependency on BioPerl right now
sub translate_nucleotides {
	my ($self,$nucleotides) = @_;

	$nucleotides = uc $nucleotides;
	$nucleotides =~ tr/U/T/;

	my $amino_acids="";
	#This is a case of strict translation and doesn't account for all ambiguities
	for (my $i = 0; $i < (length($nucleotides) - 2); $i+=3) {
	my $triplet = substr($nucleotides, $i, 3); 
	if( $triplet eq "---" ) {
		$amino_acids .= "-";
		} if (exists $genetic_code{$triplet}) {
		$amino_acids .= $genetic_code{$triplet};
		} else {
		$amino_acids .= 'X';
	}
	}

	return $amino_acids;
}

sub annotate_plant_genome_kmers {
	my ($self,$Genome) = @_;

	#Load Kmers
	my $output = Bio::ModelSEED::patricenv::call_ws("get", { objects => ["/plantseed/Data/functions_kmers"] })->[0][1];
	my %Functions_Kmers = %{Bio::KBase::ObjectAPI::utilities::FROMJSON($output)};

	my %Kmers_Functions=();
	foreach my $function (keys %Functions_Kmers){
	foreach my $kmer (@{$Functions_Kmers{$function}}){
		$Kmers_Functions{$kmer}=$function;
	}
	}

	my $Kmer_Length=8;
	my %Hit_Proteins=();
	foreach my $ftr (@{$Genome->{features}}){
	my $Seq = $ftr->{protein_translation};
	my $SeqLen = length($Seq);
	next if $SeqLen < 10;
	
	for (my $frame = 0; $frame <= $Kmer_Length; $frame++){
		# run through frames
		my $SeqString = substr($Seq,$frame,$SeqLen);
		# take the relevant substring
		while($SeqString =~ /((\w){${Kmer_Length}})/gim){
		if(exists($Kmers_Functions{$1})){
			$Hit_Proteins{$ftr->{id}}{$Kmers_Functions{$1}}{$1}=1;
		}
		}
	}
	}

	#Eliminate hits that have a small number of kmers
	#Not employed at time
	my $Kmer_Threshold = 1;
	my %Deleted_Proteins=();
	foreach my $protein (keys %Hit_Proteins){
	my %Deleted_Functions=();
	foreach my $function (keys %{$Hit_Proteins{$protein}}){
		my $N_Kmers = scalar(keys %{$Hit_Proteins{$protein}{$function}});
		if($N_Kmers <= $Kmer_Threshold){
		$Deleted_Functions{$function}=1;
		}
	}
	
	foreach my $function (keys %Deleted_Functions){
		delete($Hit_Proteins{$protein}{$function});
	}
	
	if(scalar(keys %{$Hit_Proteins{$protein}})==0){
		$Deleted_Proteins{$protein}=1;
	}
	}

	foreach my $protein (keys %Deleted_Proteins){
	delete($Hit_Proteins{$protein});
	}

	#Scan for multi-hits, and, for now, ignore them
	undef(%Deleted_Proteins);
	foreach my $protein (keys %Hit_Proteins){
	next if scalar(keys %{$Hit_Proteins{$protein}})==1;
	
	my %Top_Functions=();
		foreach my $function (keys %{$Hit_Proteins{$protein}}){
			$Top_Functions{scalar(keys %{$Hit_Proteins{$protein}{$function}})}{$function}=1;
		}
	
	my $Top_Number = ( sort { $b <=> $a } keys %Top_Functions )[0];
	my $Top_Function = ( keys %{$Top_Functions{$Top_Number}} )[0];
	if(scalar(keys %{$Top_Functions{$Top_Number}})>1){
		$Deleted_Proteins{$protein}=1;
	}else{
		$Hit_Proteins{$protein}={ $Top_Function => $Hit_Proteins{$protein}{$Top_Function} };
	}
	}
	
	foreach my $protein (keys %Deleted_Proteins){
	delete($Hit_Proteins{$protein});
	}

	return \%Hit_Proteins;
}

sub annotate_plant_genome_blast {
	my ($self,$Genome) = @_;

	#Create job directory
	my @chars = ("A".."Z", "a".."z", 0..9);
	my $job = "";;
	$job .= $chars[rand @chars] for 1..8;
	#$job = "hWJcfo6K";

	my $jobDir = "/scratch/blastjobs/".$job."/";
	system("mkdir -p ".$jobDir);
	my $jobFiles = $jobDir.$Genome->{id};

	#Print out protein sequences
	open(OUT, "> ".$jobFiles.".fasta");
	foreach my $ftr (@{$Genome->{features}}){
		print OUT ">".$ftr->{id}."\n";
		print OUT join("\n", $ftr->{protein_translation} =~ m/.{1,60}/g)."\n";
	}
	close(OUT);
		
	#BLAST against NR
	my $ua = LWP::UserAgent->new();

	my $output = Bio::ModelSEED::patricenv::call_ws("get", { objects => ["/plantseed/Data/plants_nr"] })->[0];
	my $shock_url = $output->[0][11]."?download";

	my $token = Bio::KBase::utilities::token();
	my $res = $ua->get($shock_url,Authorization => "OAuth " . $token);
	my $raw_data = $res->{_content};

	open(OUT, "> ".$jobDir."plants_nr.tar.gz");
	binmode(OUT);
	print OUT $raw_data;
	close(OUT);
	system("tar -xzf ".$jobDir."plants_nr.tar.gz -C ".$jobDir);

	my($wtr, $rdr, $err, $errstr, $pid);
	use Symbol 'gensym'; $err = gensym;
	use IPC::Open3;

	my $Command = "blastp";

#	my @Command_Array = ("nice -n 10 ".$Command);
	my @Command_Array = ($Command);
	push(@Command_Array,"-evalue");push(@Command_Array,"1.0e-7");
	push(@Command_Array,"-outfmt");push(@Command_Array,"6");
	push(@Command_Array,"-db");push(@Command_Array,$jobDir."PlantSEED_Exemplars_NR");
	push(@Command_Array,"-query");push(@Command_Array,$jobFiles.".fasta");
	push(@Command_Array,"-out");push(@Command_Array,$jobFiles.".sims");
	my $cmd=join(" ",@Command_Array);

	open(OUT, "> ".$jobDir."Run_Blast.sh");
	print OUT "#!/bin/bash\n".$cmd."\n";
	close(OUT);

	$pid=open3($wtr, $rdr, $err,$cmd);

	$errstr="";
	while(<$err>){$errstr.=$_;}

	waitpid($pid, 0);

	if(length($errstr)>0){print "ERR: ".$errstr;}

	$output = Bio::ModelSEED::patricenv::call_ws("get", { objects => ["/plantseed/Data/exemplar_families"] })->[0][1];
	my $exemplars = Bio::KBase::ObjectAPI::utilities::FROMJSON($output);

	$output = Bio::ModelSEED::patricenv::call_ws("get", { objects => ["/plantseed/Data/isofunctional_families"] })->[0][1];
	my $families = Bio::KBase::ObjectAPI::utilities::FROMJSON($output);

	open(FH, "< ".$jobFiles.".sims");
	my @Lines=();
	my %Ftrs_Sims=();
	my $Current_Ftr="";
	while(<FH>){
		chomp;
		
		my @temp=split(/\t/,$_,-1);
		next unless $temp[10] < 1e-10;
	
		$Current_Ftr = $temp[0];
		my $identity = $temp[2]/100.0;
		$Ftrs_Sims{$Current_Ftr}{$temp[1]}={bitscore=>$temp[11],identity=>sprintf("%.2f",$identity),line=>$_};
	
		if(exists($exemplars->{$temp[1]})){
			foreach my $ortholog_spp (keys %{$families->{$exemplars->{$temp[1]}}}){
			my ($spp,$ortholog)=split(/\|\|/,$ortholog_spp);
			my $line = $Current_Ftr."\t".$ortholog."\t".$families->{$exemplars->{$temp[1]}}{$ortholog_spp}."\t".join("\t",@temp[3..$#temp]);
			$Ftrs_Sims{$Current_Ftr}{$ortholog}={bitscore=>$temp[11],identity=>$families->{$exemplars->{$temp[1]}}{$ortholog_spp},line=>$line};
			}
		}
	}
	close(FH);

	my @Sim_Objects=();
	my $Sims = {};
	my $Sims_Index = 0;
	my $N_Sims = 0;
	my $Ftr_Index = {};
	my $Exems = {};
	foreach my $ftr (sort keys %Ftrs_Sims){
		foreach my $sim ( sort { $Ftrs_Sims{$ftr}{$a}{bitscore} <=> $Ftrs_Sims{$ftr}{$b}{bitscore} || 
						 $Ftrs_Sims{$ftr}{$a}{identity} <=> $Ftrs_Sims{$ftr}{$b}{identity} } keys %{$Ftrs_Sims{$ftr}} ){
			
			my $line = $Ftrs_Sims{$ftr}{$sim}{line};
			my @temp=split(/\t/,$line,-1);
			my ($query,$hit,$percent,$evalue,$bitscore) = @temp[0,1,2,10,11];
	
			if($percent > 1){
				$percent = $percent/100.0;
				$percent = sprintf("%.2f",$percent);
			}
	
			if(exists($exemplars->{$hit})){
				$Exems->{$hit}{$query}=1;
			}
			
			if(scalar(keys %$Sims)>=1000 && !exists($Sims->{$query})){
			push(@Sim_Objects,Bio::KBase::ObjectAPI::utilities::TOJSON($Sims));
			
			undef($Sims);
			$Sims_Index++;
			}
			
			my $ftr_json = { hit_id => $hit, percent_id => $percent, e_value => $evalue, bit_score => $bitscore };
			$Sims->{$query} = [] if !exists($Sims->{$query});
			push(@{$Sims->{$query}},$ftr_json);
			$N_Sims++;
			if(exists($Ftr_Index->{$query}) && $Ftr_Index->{$query} != $Sims_Index){
			print "Warning";
			}
			$Ftr_Index->{$query}=$Sims_Index;
		}
	}

	#Last one
	push(@Sim_Objects,Bio::KBase::ObjectAPI::utilities::TOJSON($Sims));

	$output = { hits => $N_Sims, sims => \@Sim_Objects, index => $Ftr_Index, exems => $Exems };
	return $output;
}

sub list_model_fba {
	my($self,$model) = @_;
	my $list = Bio::ModelSEED::patricenv::call_ws("ls",{
		paths => [$model."/fba"],
		excludeDirectories => 1,
		excludeObjects => 0,
		recursive => 1,
		query => {type => "fba"}
	});
	my $output = [];
	if (defined($list->{$model."/fba"})) {
		$list = $list->{$model."/fba"};
		for (my $i=0; $i < @{$list}; $i++) {
			push(@{$output},{
				rundate => $list->[$i]->[3],
				id => $list->[$i]->[0],
				"ref" => $list->[$i]->[2].$list->[$i]->[0],
				media_ref => $list->[$i]->[7]->{media},
				objective => $list->[$i]->[7]->{objective},
				objective_function => $list->[$i]->[8]->{objective_function},				
			});
		}
	}
	$output = [sort { $b->{rundate} cmp $a->{rundate} } @{$output}];
	return $output;
}

sub list_model_gapfills {
	my($self,$model,$includemetadata) = @_;
	my $list = Bio::ModelSEED::patricenv::call_ws("ls",{
		paths => [$model."/gapfilling"],
		excludeDirectories => 1,
		excludeObjects => 0,
		recursive => 1,
		query => {type => "fba"}
	});
	my $output = [];
	if (defined($list->{$model."/gapfilling"})) {
		$list = $list->{$model."/gapfilling"};
		for (my $i=0; $i < @{$list}; $i++) {
			push(@{$output},{
				rundate => $list->[$i]->[3],
				id => $list->[$i]->[0],
				"ref" => $list->[$i]->[2].$list->[$i]->[0],
				media_ref => $list->[$i]->[7]->{media},
				integrated => $list->[$i]->[7]->{integrated},
				integrated_solution => $list->[$i]->[7]->{integrated_solution},
				solution_reactions => []				
			});
			if (defined($list->[$i]->[7]->{solutiondata})) {
				$output->[$i]->{solution_reactions} = Bio::KBase::ObjectAPI::utilities::FROMJSON($list->[$i]->[7]->{solutiondata});
				for (my $j=0; $j < @{$output->[$i]->{solution_reactions}}; $j++) {
					for (my $k=0; $k < @{$output->[$i]->{solution_reactions}->[$j]}; $k++) {
						my $comp = "c";
						if ($output->[$i]->{solution_reactions}->[$j]->[$k]->{compartment_ref} =~ m/\/([^\/]+)$/) {
							$comp = $1;
						}
						$output->[$i]->{solution_reactions}->[$j]->[$k] = {
							direction => $output->[$i]->{solution_reactions}->[$j]->[$k]->{direction},
							reaction => $output->[$i]->{solution_reactions}->[$j]->[$k]->{reaction_ref},
							compartment => $comp.$output->[$i]->{solution_reactions}->[$j]->[$k]->{compartmentIndex}
						};
					}
				}
			}
			if ($includemetadata == 1) {
				$output->[$i]->{metadata} = $list->[$i]->[7];
			}
		}
	}
	$output = [sort { $b->{rundate} cmp $a->{rundate} } @{$output}];
	return $output;
}

sub list_models {
	my ($self,$input) = @_;
	$input = Bio::KBase::utilities::args($input,[],{
		path => "/".Bio::KBase::utilities::user_id()."/".Bio::KBase::utilities::conf("ProbModelSEED","home_dir")."/"
	});


	#Functionality to ensure that the modelseed and plantseed folders are present for each users, even if empty
	my $root = "/".(split(/\//,$input->{path}))[1];
	my $rootlist = Bio::ModelSEED::patricenv::call_ws("ls",{
		paths => [$root],
		recursive => 0,
		excludeDirectories => 0
	});
	my ($modelseed,$plantseed)=(0,0);
	foreach my $listing (@{$rootlist->{$root}}){
		if($listing->[0] eq "modelseed"){
		$modelseed=1;
		}
		if($listing->[0] eq "plantseed"){
		$plantseed=1;
		}
	}

	if(!$modelseed){
		Bio::ModelSEED::patricenv::call_ws("create", {objects => [[$root."/modelseed","folder",{},undef]]});
	}

	if(!$plantseed){
		Bio::ModelSEED::patricenv::call_ws("create", {objects => [[$root."/plantseed","folder",{},undef]]});
	}

	my $list = Bio::ModelSEED::patricenv::call_ws("ls",{
		paths => [$input->{path}],
		recursive => 0,
		excludeDirectories => 0,
		query => {type => "modelfolder"}
	});
	my $output = {};
	if (defined($list->{$input->{path}})) {
		$list = $list->{$input->{path}};
		for (my $j=0; $j < @{$list}; $j++) {
			#Skip empty models
			my $key = $list->[$j]->[2].$list->[$j]->[0];
			$output->{$key}->{id} = $list->[$j]->[0];
			$output->{$key}->{rundate} = $list->[$j]->[3];
			$output->{$key}->{"ref"} = $list->[$j]->[2].$list->[$j]->[0];
			if (defined($list->[$j]->[7]->{status})) {
				$output->{$key}->{status} = $list->[$j]->[7]->{status};
				$output->{$key}->{status_timestamp} = $list->[$j]->[7]->{status_timestamp};
				if (defined($list->[$j]->[7]->{status_error})) {
					$output->{$key}->{status_error} = $list->[$j]->[7]->{status_error};
				}
			} else {
				$output->{$key}->{status} = "complete";
			}
			if (!defined($list->[$j]->[7]->{num_reactions})) {
				if ($output->{$key}->{status} eq "complete") {
					$output->{$key}->{status} = "failed";
				}
			} else {
				$output->{$key}->{source} = $list->[$j]->[7]->{source};
				$output->{$key}->{source_id} = $list->[$j]->[7]->{source_id};
				$output->{$key}->{name} = $list->[$j]->[7]->{name};
				$output->{$key}->{type} = $list->[$j]->[7]->{type};
				$output->{$key}->{template_ref} = $list->[$j]->[7]->{template_ref};
				$output->{$key}->{num_genes} = $list->[$j]->[7]->{num_genes};
				$output->{$key}->{num_compounds} = $list->[$j]->[7]->{num_compounds};
				$output->{$key}->{num_reactions} = $list->[$j]->[7]->{num_reactions};
				$output->{$key}->{num_biomasses} = $list->[$j]->[7]->{num_biomasses};
				$output->{$key}->{num_biomass_compounds} = $list->[$j]->[7]->{num_biomass_compounds};
				$output->{$key}->{num_compartments} = $list->[$j]->[7]->{num_compartments};				
				$output->{$key}->{gene_associated_reactions} = $list->[$j]->[7]->{gene_associated_reactions};
				$output->{$key}->{gapfilled_reactions} = $list->[$j]->[7]->{gapfilled_reactions};
				$output->{$key}->{fba_count} = $list->[$j]->[7]->{fba_count};
				$output->{$key}->{integrated_gapfills} = $list->[$j]->[7]->{integrated_gapfills};
				$output->{$key}->{unintegrated_gapfills} = $list->[$j]->[7]->{unintegrated_gapfills};	
			}
		}
	}
	return $output;
}

sub delete_model_objects {
	my($self,$model,$ids,$type) = @_;
	my $output = {};
	my $idhash = {};
	for (my $i=0; $i < @{$ids}; $i++) {
		$idhash->{$ids->[$i]} = 1;
		$idhash->{$ids->[$i].".fluxtbl"} = 1;
		$idhash->{$ids->[$i].".jobresult"} = 1;
		$idhash->{$ids->[$i].".gftbl"} = 1;
	}
	my $folder = "/fba";
	my $modelobj;
	if ($type eq "gapfilling") {
		$folder = "/gapfilling";
		$modelobj = $self->get_object($model);
	}
	my $list = Bio::ModelSEED::patricenv::call_ws("ls",{
		paths => [$model.$folder],
		excludeDirectories => 1,
		excludeObjects => 0,
		recursive => 1
	});
	$list = $list->{$model.$folder};
	for (my $i=0; $i < @{$list}; $i++) {
		my $selected = 0;
		if (defined($idhash->{$list->[$i]->[0]})) {
			if ($type eq "gapfilling") {
				$modelobj->deleteGapfillSolution({gapfill => $list->[$i]->[0]});	
			}
			my $list = Bio::ModelSEED::patricenv::call_ws("delete",{
				objects => [$list->[$i]->[2].$list->[$i]->[0]],
			});
			$selected = 1;
		} elsif ($list->[$i]->[0] =~ m/(.+)\.[^\.]+$/) {
			if (defined($idhash->{$1})) {
				my $list = Bio::ModelSEED::patricenv::call_ws("delete",{
					objects => [$list->[$i]->[2].$list->[$i]->[0]],
				});
			}
			$selected = 1;
		}
		if ($selected == 1) {
			$output->{$list->[$i]->[0]} = {
				rundate => $list->[$i]->[3],
				id => $list->[$i]->[0],
				"ref" => $list->[$i]->[2].$list->[$i]->[0],
				media_ref => $list->[$i]->[7]->{media},				
			};
			if ($type eq "gapfilling") {
				$output->{$list->[$i]->[0]}->{integrated} = $list->[$i]->[7]->{integrated};
				$output->{$list->[$i]->[0]}->{integrated_solution} = $list->[$i]->[7]->{integrated_solution};
			} else {
				$output->{$list->[$i]->[0]}->{objective} = $list->[$i]->[7]->{objective};
				$output->{$list->[$i]->[0]}->{objective_function} = $list->[$i]->[7]->{objective_function};
			}
		}
	}
	return $output;
}

sub integrate_model_gapfills {
	my($self,$model,$intlist) = @_;
	$model = $self->get_object($model);
	for (my $i=0; $i < @{$intlist}; $i++) {
		$model->integrateGapfillSolution({
			gapfill => $intlist->[$i]
		});
	}
	$self->save_object($model->wsmeta()->[2].$model->wsmeta()->[0],$model,"model");
}

sub unintegrate_model_gapfills {
	my($self,$model,$intlist) = @_;
	$model = $self->get_object($model);
	for (my $i=0; $i < @{$intlist}; $i++) {
		$model->unintegrateGapfillSolution({
			gapfill => $intlist->[$i]
		});
	}
	$self->save_object($model->wsmeta()->[2].$model->wsmeta()->[0],$model,"model");
}

sub util_mongodb {
	my($self,$dbname) = @_;
	if (!defined($self->{_mongodb}->{$dbname})) {
		my $config = {
			host => Bio::KBase::utilities::conf("ProbModelSEED","mongodb-host"),
			username => Bio::KBase::utilities::conf("ProbModelSEED","mongodb-user"),
			password => Bio::KBase::utilities::conf("ProbModelSEED","mongodb-pwd"),
			db_name => "modelseed",
			auto_connect => 1,
			auto_reconnect => 1
		};
		if(!defined($config->{username}) || length($config->{username}) == 0 || $config->{username} eq "null") {
			delete $config->{username};
			delete $config->{password};
		}
		my $conn = MongoDB::Connection->new(%$config);
		if (!defined($conn)) {
			Bio::KBase::ObjectAPI::utilities::error("Unable to connect: $@");
		}
		$self->{_mongodb}->{$dbname} = $conn->get_database($dbname);
	}
	return $self->{_mongodb}->{$dbname};	
}

sub run_server_checks {
	my($self) = @_;
	if (Bio::KBase::utilities::conf("ProbModelSEED","server_checks") > 0) {
		my $random_number = int(rand(100));
		if ($random_number < 100*Bio::KBase::utilities::conf("ProbModelSEED","server_checks")) {
			my $cursor = $self->util_mongodb("modelseed")->get_collection('events')->find({
				id => "error_notification"
			});
			my $object = $cursor->next;
			if (time()-$object->{"time"} > 86400) {
				$self->util_mongodb("modelseed")->get_collection('events')->find_and_modify({
					query => { id => "error_notification" },
					update => { "time" => time() }
				});
				$cursor = $self->util_mongodb("modelseed")->get_collection('events')->find({
					id => "scheduler_runs_job"
				});
				$object = $cursor->next;
				if (time()-$object->{"time"} < 43200) {
					print "No jobs run in 6 hours!";
				}
				$cursor = $self->util_mongodb("modelseed")->get_collection('events')->find({
					id => "scheduler_checks_job"
				});
				$object = $cursor->next;
				if (time()-$object->{"time"} < 3600) {
					print "No checks of the queue in 1 hour!";
				}
			}
			#"ukdordyefxrj26p8cd4qp1xneyyzeu"
		}
	}
}

sub create_jobs {
	my($self,$input) = @_;
	$input = Bio::KBase::utilities::args($input,["jobs"],{});
	my $output = {};
	for (my $i=0; $i < @{$input->{jobs}}; $i++) {
		my $idobj = $self->util_mongodb("modelseed")->get_collection('counters')->find_and_modify({
			query => { _id => "job_ids" },
			update => { '$inc' => { seq => 1 } }
		});
		my $id = $idobj->{seq};
		my $job = {
			id => $id,
			app => $input->{jobs}->[$i]->{app},
			parameters => $input->{jobs}->[$i]->{parameters},
			status => "queued",
			submit_time => DateTime->now()->datetime(),
			error => "none",
			owner => Bio::KBase::utilities::user_id(),
			token => Bio::KBase::utilities::token()
		};
		$self->util_mongodb("modelseed")->get_collection('jobs')->insert($job);
		$output->{$job->{id}} = $job;
	}
	return $output;
}

sub manage_jobs {
	my($self,$input) = @_;
	$input = Bio::KBase::utilities::args($input,["jobs","action"],{
		errors => {},
		reports => {},
		status => undef,
		scheduler => 0
	});
	for (my $i=0; $i < @{$input->{jobs}}; $i++) {
		$input->{jobs}->[$i] += 0;
	}
	my $output = {};
	my $query = {id => {'$in' => $input->{jobs}}};
	if (defined($input->{status})) {
		$query->{status} = $input->{status};
	}
	my $cursor = $self->util_mongodb("modelseed")->get_collection('jobs')->find($query);
	while (my $object = $cursor->next) {
		$output->{$object->{id}} = $object;
		delete $output->{$object->{id}}->{_id};
	};
	foreach my $key (keys(%{$output})) {
		my $obj = $output->{$key};
		if ($input->{action} eq "delete") {
			my $query = {id => $obj->{id}};
			$self->util_mongodb("modelseed")->get_collection('jobs')->remove($query);
			$obj->{status} = "deleted";
		} elsif ($input->{action} eq "finish") {
			my $update = {
				status => "completed",
				completed_time => DateTime->now()->datetime()
			};
			$obj->{status} = $update->{status};
			$obj->{completed_time} = $update->{completed_time};
			if (defined($input->{reports}->{$obj->{id}})) {
				$update->{report} = $input->{reports}->{$obj->{id}};
			}
			$obj->{report} = $input->{reports}->{$obj->{id}};
			if (defined($input->{errors}->{$obj->{id}})) {
				$update->{error} = $input->{errors}->{$obj->{id}};
				$obj->{status} = "failed";
				$update->{status} = "failed";
				$obj->{error} = $input->{errors}->{$obj->{id}};
			}
			$self->util_mongodb("modelseed")->get_collection('jobs')->find_and_modify({
				query => { id => $obj->{id} },
				update => { '$set' => $update}
			});
		} elsif ($input->{action} eq "reset") {	
			my $update = {
				status => "queued",
				error => "",
				report => "",
			};
			$obj->{status} = $update->{status};
			$obj->{error} = $update->{error};
			$obj->{report} = $update->{report};
			$self->util_mongodb("modelseed")->get_collection('jobs')->find_and_modify({
				query => { id => $obj->{id} },
				update => { '$set' => $update}
			});
		} elsif ($input->{action} eq "start") {
			my $update = {
				status => "running",
				start_time => DateTime->now()->datetime(),
				error => "",
				report => "",
				pid => $input->{reports}->{$obj->{id}}
			};
			if ($input->{scheduler} == 1) {
				$self->util_mongodb("modelseed")->get_collection('events')->find_and_modify({
					query => { id => "scheduler_runs_job" },
					update => { '$set' => {"time" => time()}}
				});
			}
			$obj->{status} = $update->{status};
			$obj->{start_time} = $update->{start_time};
			$obj->{error} = $update->{error};
			$obj->{report} = $update->{report};
			$obj->{pid} = $update->{pid};
			$self->util_mongodb("modelseed")->get_collection('jobs')->find_and_modify({
				query => { id => $obj->{id} },
				update => { '$set' => $update}
			});
		}
	}
	return $output;
}

sub check_jobs {
	my($self,$input) = @_;
	$input = Bio::KBase::utilities::args($input,[],{
		jobs => undef,
		exclude_failed => 0,
		exclude_running => 0,
		exclude_complete => 0,
		exclude_queued => 0,
		admin => 0,
		scheduler => 0
	});
	my $output = {};
	if ($input->{scheduler} == 1) {
		$self->util_mongodb("modelseed")->get_collection('events')->find_and_modify({
			query => { id => "scheduler_checks_job" },
			update => { '$set' => {"time" => time()}}
		});
	}
	my $query = {
		owner => Bio::KBase::utilities::user_id()
	};
	if (Bio::KBase::utilities::user_id() eq "chenry" && $input->{admin} == 1) {
		$query = {};
	}
	if (defined($input->{jobs})) {
		$query->{id} = {'$in' => $input->{jobs}};
	}
	if ($input->{exclude_failed} == 1 || $input->{exclude_running} == 1 || $input->{exclude_complete} == 1 || $input->{exclude_queued} == 1) {
		my $status = [];
		if ($input->{exclude_failed} == 0) {
			push(@{$status},"failed");
		}
		if ($input->{exclude_running} == 0) {
			push(@{$status},"running");
		}
		if ($input->{exclude_complete} == 0) {
			push(@{$status},"completed");
		}
		if ($input->{exclude_queued} == 0) {
			push(@{$status},"queued");
		}
		$query->{status} = {'$in' => $status};
	}
	my $cursor = $self->util_mongodb("modelseed")->get_collection('jobs')->find($query);
	while (my $object = $cursor->next) {
		$output->{$object->{id}} = $object;
		delete $output->{$object->{id}}->{_id};
	};
	return $output;
}
#****************************************************************************
#Apps
#****************************************************************************
sub app_harness {
	my($self,$command,$parameters) = @_;
	if (Bio::KBase::utilities::conf("ProbModelSEED","run_as_app") == 1) {
		Bio::KBase::utilities::log($command.": issuing app");
		my $output;
		if (Bio::KBase::utilities::conf("ProbModelSEED","appservice_url") eq "self") {
			$output = $self->create_jobs({jobs => [{
				app => $command,
				parameters => $parameters,
			}]});
			
		} else {
			$output = $self->app_service()->CreateJobs({jobs => [{
				app => $command,
				parameters => $parameters,
			}]});
		}
		Bio::KBase::utilities::log($command.": app issued");
		my $keys = [keys(%{$output})];
		return $keys->[0];
	} else {
		Bio::KBase::utilities::log($command.": job started");
		my $output = $self->$command($parameters);
		if(defined($output) && ref($output) eq "HASH" && exists($output->{report_ref})){
			Bio::ModelSEED::patricenv::create_report({
			"ref" => $output->{report_ref},
			output => $output});
		}
		Bio::KBase::utilities::log($command.": job done (elapsed time ".Bio::KBase::utilities::elapsedtime().")");
		return $output;
	}
}

sub logger {
	my($self) = @_;
	if (!defined($self->{_logger})) {
	   	if (!-e Bio::KBase::utilities::conf("ProbModelSEED","config_directory")."/ProbModelSEED.conf") {
			if (!-d Bio::KBase::utilities::conf("ProbModelSEED","config_directory")) {
				File::Path::mkpath (Bio::KBase::utilities::conf("ProbModelSEED","config_directory"));
			}
			Bio::KBase::ObjectAPI::utilities::PRINTFILE(Bio::KBase::utilities::conf("ProbModelSEED","config_directory")."ProbModelSEED.conf",[
				"############################################################",
				"# A simple root logger with a Log::Log4perl::Appender::File ",
				"# file appender in Perl.",
				"############################################################",
				"log4perl.rootLogger=INFO, LOGFILE",
				"",
				"log4perl.appender.LOGFILE=Log::Log4perl::Appender::File",
				"log4perl.appender.LOGFILE.filename=".Bio::KBase::utilities::conf("ProbModelSEED","config_directory")."ProbModelSEED.log",
				"log4perl.appender.LOGFILE.mode=append",
				"",
				"log4perl.appender.LOGFILE.layout=PatternLayout",
				"log4perl.appender.LOGFILE.layout.ConversionPattern=[%r] %F %L %c - %m%n",
			]);
		}
	   	Log::Log4perl::init(Bio::KBase::utilities::conf("ProbModelSEED","config_directory")."ProbModelSEED.conf");
	   	$self->{_logger} = Log::Log4perl->get_logger("ProbModelSEEDHelper");
	}
	return $self->{_logger};
}

sub util_log {
	my($self,$message,$type) = @_;
	if (!defined($type)) {
		$type = "info";
	}
	if ($type eq "stdout") {
		print $message."\n";
	} elsif ($type eq "stderr") {
		print STDERR $message."\n";
	} else {
		$self->logger()->$type('<msg type="'.$type.'" time="'.DateTime->now()->datetime().'" pid="'.Bio::KBase::utilities::processid().'" user="'.Bio::KBase::utilities::user_id().'">'."\n".$message."\n</msg>\n");
	}
}

sub util_get_object {
	my($self,$ref,$parameters) = @_;
	my $obj;
	if ($ref =~ m/^PATRIC:\/*(.+)/) {
		return $self->retrieve_PATRIC_genome($1);
	} elsif ($ref =~ m/^PATRICSOLR:\/*(.+)/) {
		Bio::KBase::utilities::setconf("ProbModelSEED","old_models",1);
		return $self->retrieve_PATRIC_genome($1);
	} elsif ($ref =~ m/^REFSEQ:\/*(.+)/) {
		return $self->retrieve_PATRIC_genome($1,1);
	} elsif ($ref =~ m/^PUBSEED:\/*(.+)/) {
		return $self->retrieve_SEED_genome($1);
	} elsif ($ref =~ m/^RAST:\/*(.+)/) {
		return $self->retrieve_RAST_genome($1);
	} elsif ($ref =~ m/^NewKBaseModelTemplates\/(.+)/) {
		my $translation = {
			GramPosModelTemplate => "GramPositive.modeltemplate",
			GramNegModelTemplate => "GramNegative.modeltemplate",
			PlantModelTemplate => "plant.modeltemplate"
		};
		$ref = Bio::KBase::utilities::conf("ProbModelSEED","template_dir").$translation->{$1};
		$obj = $self->get_object($ref);
	} else {
		$obj = $self->get_object($ref);
		if (defined($obj) && ref($obj) ne "Bio::KBase::ObjectAPI::KBaseGenomes::Genome" && ref($obj) ne "" && defined($obj->{output_files})) {
			my $output = $obj->{output_files};
			for (my $i=0; $i < @{$obj->{output_files}}; $i++) {
				if ($obj->{output_files}->[$i]->[0] =~ m/\.genome$/) {
					$ref = $obj->{output_files}->[$i]->[0];
				}
			}
			$obj = $self->get_object($ref,"genome");
		}
	}
	return $obj;
}

sub util_save_object {
	my($self,$object,$ref,$parameters) = @_;
	my $original_output;
	if (defined($parameters->{type}) && defined($typetrans->{$parameters->{type}})) {
		$parameters->{type} = $typetrans->{$parameters->{type}};
	}
	if (!defined($parameters->{metadata})) {
		$parameters->{metadata} = {};
	}
	if ($parameters->{type} eq "fba") {
		if ($analysis_type eq "GF") {
			$ref = $object->fbamodel()->_reference()."/gapfilling/".$object->id();
		} else {
			$ref = $object->fbamodel()->_reference()."/fba/".$object->id();
		}
		$ref =~ s/\|\|//g;
		$original_output = $self->save_object($ref,$object,$parameters->{type},$parameters->{metadata});
	} else {
		$original_output = $self->save_object($ref,$object,$parameters->{type},$parameters->{metadata});
	}
	return [
		$original_output->[0],
		$original_output->[0],
		$original_output->[1],
		$original_output->[3],
		0,
		$original_output->[5],
		$original_output->[2],
		$original_output->[2],
		0,
		$original_output->[6],
		$original_output->[7],
		$original_output->[8]
	];
}

sub util_store {
	my($self) = @_;
	return $self->PATRICStore();
}

sub util_parserefs {
	my($self,$ref) = @_;
	my $ws;
	my $id;
	if ($ref =~ m/^(.+)\/([^\/]+)$/) {
		$ws = $1;
		$id = $2;
	} elsif ($ref =~ m/^(.+:)([^\/]+)$/) {
		$ws = $1;
		$id = $2;
	}
	return ($ws,$id);
}

sub util_report {
	my($self,$args) = @_;
	#TODO: may need to do something with this report data
}

sub ComputeReactionProbabilities {
	my($self,$parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,["genome", "template", "rxnprobs"], {});
	Bio::KBase::utilities::log("Calculating reaction likelihoods for ".$parameters->{genome}." with template ".$parameters->{template});
	my $cmd = Bio::KBase::utilities::conf("ProbModelSEED","probannobin")." ".$parameters->{genome}." ".$parameters->{template}." ".$parameters->{rxnprobs}." --token '".Bio::KBase::utilities::token()."'";
	system($cmd);
	if ($? != 0) {
		$self->error("Calculating reaction likelihoods failed!");
	}
	Bio::KBase::utilities::log("Finished calculating reaction likelihoods");
	return {
		rxnprobs_ref => $parameters->{rxnprobs},
		report_ref => $parameters->{rxnprobs}.".jobresult"
	};
}

sub EditModel {
	my($self,$parameters) = @_;
	(my $ws,my $id) = $self->util_parserefs($parameters->{model});
	my $output = Bio::KBase::ObjectAPI::functions::func_edit_metabolic_model({
		workspace => $ws,
		fbamodel_id => $id,
		data => {
			biomass_changes => $parameters->{biomass_changes},
			reactions_to_remove => $parameters->{reactions_to_remove},
			reactions_to_add => $parameters->{reactions_to_add},
			reactions_to_modify => $parameters->{reactions_to_modify},
		}
	});
	$output->{detailed_edit_results}->{report_ref} = $parameters->{model}."/edit.jobresult";
	return $output->{detailed_edit_results};
}

sub ModelReconstruction {
	my($self,$parameters) = @_;
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
		$self->create_genome_from_shock({
			shock_id => $parameters->{shock_id},
			annotate => 1,
			output_path => $folder,
			genome_type => $parameters->{genome_type},
			genome_id => $parameters->{output_file},
			annotation_process => $parameters->{annotation_process}
		});
		$parameters->{genome} = $folder."/genome";
	} elsif ($parameters->{genome} =~ m/RAST:/ || $parameters->{genome} =~ m/PATRIC:/) {
		my $GenomeObj = $self->get_genome($parameters->{genome});
		Bio::ModelSEED::patricenv::call_ws("create", { objects => [ [$folder."/genome", "genome", {}, $GenomeObj->serializeToDB()] ] });
		$parameters->{genome} = $folder."/genome";
	}elsif ( $parameters->{genome_type} eq "plant" && $parameters->{annotation_process} eq "blast" ){
		my $kmers = $parameters->{annotation_process} eq "kmer" ? 1 : 0;
		my $blast = $parameters->{annotation_process} eq "blast" ? 1 : 0;
	
		my $GenomeObj = $self->get_object($folder."/genome")->serializeToDB();
		my $MinGenomeObj = $self->get_object($folder."/.plantseed_data/minimal_genome");
		my $annotation_summary = $self->annotate_plant_genome({genome => $GenomeObj,
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
		($parameters->{template_workspace},$parameters->{template_id}) = $self->util_parserefs($parameters->{template_model});
	} else {
		$parameters->{template_id} = $parameters->{template_model};
	}
	($parameters->{genome_workspace},$parameters->{genome_id}) = $self->util_parserefs($parameters->{genome});	
	$parameters->{workspace} = $parameters->{output_path};
	$parameters->{fbamodel_output_id} = $parameters->{output_file};
	delete $parameters->{genome};
	delete $parameters->{template_model};
	my $datachannel = {};
	print Data::Dumper->Dump([$parameters]);
	Bio::KBase::ObjectAPI::functions::func_build_metabolic_model($parameters,$datachannel);
	#Now compute reaction probabilities if they are needed for gapfilling or probanno model building
	if ($parameters->{probanno} == 1 || ($parameters->{gapfill} == 1 && $parameters->{probannogapfill} == 1)) {
    	my $genomeref = $folder."/genome";
    	my $templateref = $datachannel->{fbamodel}->template()->_reference();
    	$templateref =~ s/\|\|$//; # Remove the extraneous || at the end of the reference
    	my $rxnprobsref = $folder."/rxnprobs";
    	$self->ComputeReactionProbabilities({
    		genome => $genomeref,
    		template => $templateref,
    		rxnprobs => $rxnprobsref
    	});
    	$datachannel->{fbamodel}->rxnprobs_ref($rxnprobsref);
	}
	if ($parameters->{gapfill} == 1) {
    	$self->GapfillModel({
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
    	if ($parameters->{predict_essentiality} == 1) {
    		$self->FluxBalanceAnalysis({
	    		model => $folder,
	    		media => $parameters->{media},
	    		simulate_ko => 1
	    	},$datachannel->{fbamodel});
    	}	
    }
    return {
		fbamodel_ref => $folder,
		report_ref => $folder."/jobresult"
	};
}

sub FluxBalanceAnalysis {
	my($self,$parameters,$model) = @_;
	$analysis_type = "FBA";
	$parameters = Bio::KBase::utilities::args($parameters,["model"],{
		media => undef,
		fva => 1,
		simulate_ko => 0,
		minimize_flux => 1,
		objective_fraction => 1,
		target_reaction => "bio1",
		thermodynamic_constraints => 0,
		find_min_media => 0,
		all_reversible => 0,
		feature_ko_list => [],
		reaction_ko_list => [],
		custom_bound_list => [],
		media_supplement_list => [],
		expseries => undef,
		expression_condition => undef,
		exp_threshold_percentile => 0.5,
		exp_threshold_margin => 0.1,
		activation_coefficient => 0.5,
		omega => 0,
		max_c_uptake => undef,
		max_n_uptake => undef,
		max_p_uptake => undef,
		max_s_uptake => undef,
		max_o_uptake => undef,
		default_max_uptake => 0,
		notes => undef,
		massbalance => undef
	});
	if (defined($parameters->{use_cplex})) {
		Bio::KBase::utilities::setconf("ModelSEED","use_cplex",$parameters->{use_cplex});
	}
	if (ref($parameters->{reaction_ko_list}) ne 'ARRAY') {
		$parameters->{reaction_ko_list} = [split(/;/,$parameters->{reaction_ko_list})];
	}
	$parameters->{output_path} = $parameters->{model}."/fba";
	if (!defined($parameters->{output_file})) {
		my $list = Bio::ModelSEED::patricenv::call_ws("ls",{
			paths => [$parameters->{output_path}],
			excludeDirectories => 1,
			excludeObjects => 0,
			recursive => 1,
			query => {type => "fba"}
		});
		my $index = 0;
		if (defined($list->{$parameters->{output_path}})) {
			$list = $list->{$parameters->{output_path}};
			$index = @{$list};
			for (my $i=0; $i < @{$list}; $i++) {
				if ($list->[$i]->[0] =~ /^fba\.(\d+)$/) {
					if ($1 >= $index) {
						$index = $1+1;
					}
				}
			}
		}
		$parameters->{output_file} = "fba.".$index;
	}
	my $outputfile = $parameters->{output_path}."/".$parameters->{output_file};
	$parameters->{fva} = 1;
	$parameters->{minimize_flux} = 1;
	$parameters->{fba_output_id} = $parameters->{output_file};
	$parameters->{workspace} = $parameters->{output_path};
	if (defined($parameters->{media})) {
		($parameters->{media_workspace},$parameters->{media_id}) = $self->util_parserefs($parameters->{media});
		delete $parameters->{media};
	}
	if (defined($parameters->{expseries})) {
		($parameters->{expseries_workspace},$parameters->{expseries_id}) = $self->util_parserefs($parameters->{expseries});
		delete $parameters->{expseries};
	}
	($parameters->{fbamodel_workspace},$parameters->{fbamodel_id}) = $self->util_parserefs($parameters->{model});	
	delete $parameters->{model};
	print "RUNNING FBA:".$parameters->{workspace}."/".$parameters->{fba_output_id}."\n";
	Bio::KBase::ObjectAPI::functions::func_run_flux_balance_analysis($parameters,$model);
	return {
		fba_ref => $outputfile,
		report_ref => $outputfile.".jobresult"
	};
}

sub GapfillModel {
	my($self,$parameters,$model) = @_;
	$analysis_type = "GF";
	$parameters = Bio::KBase::utilities::args($parameters,["model"],{
		expseries => undef,
		media => undef,
		probanno => 0,
		source_model => undef,
		target_reaction => "bio1",
		thermodynamic_constraints => 0,
		comprehensive_gapfill => 0,
		feature_ko_list => [],
		reaction_ko_list => [],
		custom_bound_list => [],
		media_supplement_list => [],
		expression_condition => undef,
		exp_threshold_percentile => 0.5,
		exp_threshold_margin => 0.1,
		activation_coefficient => 0.5,
		omega => 0,
		objective_fraction => 0,
		minimum_target_flux => 0.1,
		number_of_solutions => 1,
		solver => undef,
		blacklisted_rxn_list => [],
		gauranteed_rxn_list => [],
		integrate_solution => 0
	});
	if (defined($parameters->{use_cplex})) {
		Bio::KBase::utilities::setconf("ModelSEED","use_cplex",$parameters->{use_cplex});
	}
	$parameters->{output_path} = $parameters->{model}."/gapfilling";
	if (!defined($parameters->{output_file})) {
		my $gflist = Bio::ModelSEED::patricenv::call_ws("ls",{
			paths => [$parameters->{output_path}],
			excludeDirectories => 1,
			excludeObjects => 0,
			recursive => 1,
			query => {type => "fba"}
		});
		my $index = 0;
		if (defined($gflist->{$parameters->{output_path}})) {
			$gflist = $gflist->{$parameters->{output_path}};
			$index = @{$gflist};
			for (my $i=0; $i < @{$gflist}; $i++) {
				if ($gflist->[$i]->[0] =~ /^gf\.(\d+)$/) {
					if ($1 > $index) {
						$index = $1+1;
					}
				}
			}
		}
		$parameters->{output_file} = "gf.".$index;
	}
	if (defined($parameters->{media})) {
		($parameters->{media_workspace},$parameters->{media_id}) = $self->util_parserefs($parameters->{media});
		delete $parameters->{media};
	}
	if (defined($parameters->{probanno}) && $parameters->{probanno} == 1) {
		$parameters->{probanno_id} = "rxnprobs";
		$parameters->{probanno_workspace} = $parameters->{model};
	}
	($parameters->{fbamodel_workspace},$parameters->{fbamodel_id}) = $self->util_parserefs($parameters->{model});	
	($parameters->{source_fbamodel_workspace},$parameters->{source_fbamodel_id}) = $self->util_parserefs($parameters->{source_model});	
	($parameters->{expseries_workspace},$parameters->{expseries_id}) = $self->util_parserefs($parameters->{exp_series});
	$parameters->{fbamodel_output_id} = $parameters->{fbamodel_id};
	$parameters->{gapfill_output_id} = $parameters->{output_file};
	$parameters->{workspace} = $parameters->{fbamodel_workspace};
	delete $parameters->{model};
	delete $parameters->{source_model};
	delete $parameters->{exp_series};
	delete $parameters->{probanno};
	print "RUNNING GAPFILLING:".$parameters->{workspace}."/".$parameters->{fbamodel_output_id}."\n";
	Bio::KBase::ObjectAPI::functions::func_gapfill_metabolic_model($parameters,$model);
	return {
		gapfill_ref => $parameters->{output_path}."/".$parameters->{output_file},
		fbamodel_ref => $parameters->{fbamodel_workspace}."/".$parameters->{fbamodel_id},
		report_ref => $parameters->{output_path}."/".$parameters->{output_file}.".jobresult"
	};
}

sub MergeModels {
	my($self,$parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,["models","output_file"],{
		output_path => "/".Bio::KBase::utilities::user_id()."/".Bio::KBase::utilities::conf("ProbModelSEED","home_dir")."/",
		mixed_bag_model => 0
	});
	$parameters->{fbamodel_id_list} = $parameters->{models};
	for (my $i=0; $i < @{$parameters->{fbamodel_id_list}}; $i++) {
		$parameters->{fbamodel_id_list}->[$i] = $parameters->{fbamodel_id_list}->[$i]."||";
	}
	$parameters->{fbamodel_output_id} = $parameters->{output_file};
	$parameters->{workspace} = $parameters->{output_path};
	delete $parameters->{models};
	Bio::KBase::ObjectAPI::functions::func_merge_metabolic_models_into_community_model($parameters);
	return {
		fbamodel_ref => $parameters->{output_path}."/".$parameters->{output_file},
		report_ref => $parameters->{output_path}."/".$parameters->{output_file}."/jobresult"
	};
}

sub ImportKBaseModel {
	my($self,$parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,["kbws","kbid"],{
		kbwsurl => undef,
		kbuser => undef,
		kbpassword => undef,
		kbtoken => undef,
		output_file => $parameters->{kbid},
		output_path => "/".Bio::KBase::utilities::user_id()."/".Bio::KBase::utilities::conf("ProbModelSEED","home_dir")."/"
	});
	#Making sure the output path has a slash at the end
	if (substr($parameters->{output_path},-1,1) ne "/") {
		$parameters->{output_path} .= "/";
	}
	#Retrieving model from KBase
	my $kbstore = $self->KBaseStore({
		kbuser => $parameters->{kbuser},
		kbpassword => $parameters->{kbpassword},
		kbtoken => $parameters->{kbtoken},
		kbwsurl => $parameters->{kbwsurl},
	});
	my $model = $kbstore->get_object($parameters->{kbws}."/".$parameters->{kbid});
	$model->id($parameters->{output_file});
	$model->source("ModelSEED");
	#Creating folder for imported model
	my $folder = $parameters->{output_path}.$parameters->{output_file};
	$self->save_object($folder,undef,"modelfolder");
   	#Saving contigsets inside the model folder if they exist for the genome - saved as contigset for now so no translation needed
   	my $genome = $model->genome();
   	$model->name($genome->scientific_name()." model");
   	if (defined($genome->contigset_ref())) {
   		$self->save_object($folder."/contigset",$genome->contigs(),"contigset");
   		#Resetting reference for contigset to local path
   		$genome->contigset_ref("contigset||");
   	}
   	#Saving genome inside the model folder - no translation is needed
   	$self->save_object($folder."/genome",$genome,"genome");
	#Changing template reference
	if ($model->template_ref() =~ m/228\/2\/*\d*/) {
		$model->template_ref(Bio::KBase::utilities::conf("ProbModelSEED","template_dir")."GramNegative.modeltemplate||");
	} elsif ($model->template_ref() =~ m/228\/1\/*\d*/) {
		$model->template_ref(Bio::KBase::utilities::conf("ProbModelSEED","template_dir")."GramPositive.modeltemplate||");
	} elsif ($model->template_ref() =~ m/228\/4\/*\d*/) {
		$model->template_ref(Bio::KBase::utilities::conf("ProbModelSEED","template_dir")."plant.modeltemplate||");
	}
	$model->translate_to_localrefs();
   	#Transfering gapfillings
	$self->save_object($folder."/gapfilling",undef,"folder");
	my $oldgfs = $model->gapfillings();
	$model->gapfillings([]);
	for (my $i=0; $i < @{$oldgfs}; $i++) {
		#Only transfering integrated gapfillings
		if ($oldgfs->[$i]->integrated() == 1) {
			my $oldparent = $model->parent();
			$oldgfs->[$i]->id("gf.".$i);
			$oldgfs->[$i]->gapfill_id("gf.".$i);
			my $fba;
			if (defined($oldgfs->[$i]->gapfill_ref())) {
				my $gf = $oldgfs->[$i]->gapfill();
				Bio::KBase::utilities::log($gf->serializeToDB());
				$fba = $gf->fba();
				if (defined($gf->gapfillingSolutions()->[0])) {
					$fba->add("gapfillingSolutions",$gf->gapfillingSolutions()->[0]);
				}
			} else {
				$fba = $oldgfs->[$i]->fba();
			}
			if (defined($fba->gapfillingSolutions()->[0])) {
				Bio::KBase::utilities::log("Valid gapfilling:".$parameters->{output_file}."/gapfilling/gf.".$i);
				push(@{$model->gapfillings()},$oldgfs->[$i]);
				$fba->fbamodel($model);
				$fba->id("gf.".$i);
				$oldgfs->[$i]->fba_ref($parameters->{output_file}."/gapfilling/".$fba->id()."||"); 
				$fba->translate_to_localrefs();
				if ($fba->media_ref() =~ m/\/([^\/]+)$/) {
					$fba->media_ref("/chenry/public/modelsupport/patric-media/".$1."||");
					$oldgfs->[$i]->media_ref($fba->media_ref());
				}			
				#Saving FBA object
				$fba->fbamodel_ref("../../".$model->id()."||");
				$self->save_object($folder."/gapfilling/".$fba->id(),$fba,"fba");
				my $solution = $fba->gapfillingSolutions()->[0];
				#Integrating new reactions into model
				$model->parent($self->PATRICStore());
				$fba->parent($self->PATRICStore());
				my $rxns = $solution->gapfillingSolutionReactions();
				for (my $i=0; $i < @{$rxns}; $i++) {
					my $rxn = $rxns->[$i];
					my $obj = $rxn->getLinkedObject($rxn->reaction_ref());
					if (defined($obj)) {
						my $rxnid = $rxn->reaction()->id();
						my $mdlrxn;
						my $ismdlrxn = 0;
						$mdlrxn = $model->getObject("modelreactions",$rxnid.$rxn->compartmentIndex());
						if (!defined($mdlrxn)) {
							Bio::KBase::utilities::log("Could not find ".$rxnid." in model ".$parameters->{output_file});
							$mdlrxn = $model->addModelReaction({
								reaction => $rxn->reaction()->msid(),
								compartment => $rxn->reaction()->templatecompartment()->id(),
								compartmentIndex => $rxn->compartmentIndex(),
								direction => $rxn->direction()
							});
							$mdlrxn->gapfill_data()->{$fba->id()} = "added:".$rxn->direction();
						} else {
							my $prots = $mdlrxn->modelReactionProteins();
							if (@{$prots} == 0) {
								$mdlrxn->gapfill_data()->{$fba->id()} = "added:".$rxn->direction();
							} else {
								$mdlrxn->direction("=");
								$mdlrxn->gapfill_data()->{$fba->id()} = "reversed:".$rxn->direction();
							}
						}
					}
				}
				$model->parent($oldparent);
			}
		}
	}
	$model->parent($self->PATRICStore());
	#Saving model to PATRIC
	$model->wsmeta->[0] = $parameters->{output_file};
	$model->wsmeta->[2] = $parameters->{output_path};
	$model->genome_ref($model->id()."/genome||");
	$self->save_object($parameters->{output_path}.$parameters->{output_file},$model,"model",{});
	return {
		fbamodel_ref => $parameters->{output_path}.$parameters->{output_file},
		report_ref => $parameters->{output_path}.$parameters->{output_file}."/jobresult"
	}
}

sub ExportToKBase {
	my($self,$parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,["model","kbws","kbid"],{
		kbwsurl => undef,
		kbuser => undef,
		kbpassword => undef,
		kbtoken => undef,
	});
	#Getting model
	my $model = $self->get_object($parameters->{model});
	#Getting KBase store
	my $kbstore = $self->KBaseStore({
		kbuser => $parameters->{kbuser},
		kbpassword => $parameters->{kbpassword},
		kbtoken => $parameters->{kbtoken},
		kbwsurl => $parameters->{kbwsurl},
	});
	#Getting genome
	my $genome = $model->genome();
	#Saving contig set
	if (defined($genome->{contigset_ref})) {
		my $contigs = $genome->contigs();
		$kbstore->save_object($contigs,$parameters->{kbws}."/".$parameters->{kbid}.".contigs");
		$genome->contigset_ref($parameters->{kbws}."/".$parameters->{kbid}.".contigs");
	}
	#Saving genome
	$kbstore->save_object($genome,$parameters->{kbws}."/".$parameters->{kbid}.".genome");
	#Saving gapfilling
	for (my $i=0; $i < @{$model->gapfillings()}; $i++) {
		my $fba = $model->gapfillings()->[$i]->fba();
		$model->gapfillings()->[$i]->fba_ref($genome,$parameters->{kbws}."/".$parameters->{kbid}.".".$model->gapfillings()->[$i]->id());
		$fba->fbamodel_ref($parameters->{kbws}."/".$parameters->{kbid});
		if ($fba->media_ref() =~ m/\/([^\/]+)$/) {
			$fba->media_ref("KBaseMedia/".$1);
		}
		$fba->fbamodel_ref($parameters->{kbws}."/".$parameters->{kbid});
	}
	#Saving model
	if ($model->template_ref() =~ m/GramNegative/) {
		$model->template_ref("228/2");
	} elsif ($model->template_ref() =~ m/GramPositive/) {
		$model->template_ref("228/1");
	} elsif ($model->template_ref() =~ m/plant/) {
		$model->template_ref("228/4");
	}
	$model->genome_ref($parameters->{kbws}."/".$parameters->{kbid}.".genome");
	$model->parent($kbstore);
	$kbstore->save_object($model,$parameters->{kbws}."/".$parameters->{kbid});
	return {
		fbamodel_ref => $parameters->{kbws}."/".$parameters->{kbid},
		report_ref => $parameters->{output_path}.$parameters->{output_file}."/".$parameters->{kbid}.".export.jobresult"
	};
}

sub TranslateOlderModels {
	my($self,$parameters) = @_;
	$parameters = Bio::KBase::utilities::args($parameters,["model"],{ 
		output_file => undef,
		output_path => undef
	});
	#Getting the model
	my $model = $self->get_object($parameters->{model});
	if (!defined($parameters->{output_file})) {
		$parameters->{output_file} = $model->wsmeta()->[0];
	}
	if (!defined($parameters->{output_path})) {
		$parameters->{output_path} = $model->wsmeta()->[2];
	}
	#Making sure the output path has a slash at the end
	if (substr($parameters->{output_path},-1,1) ne "/") {
		$parameters->{output_path} .= "/";
	}
	$model->id($parameters->{output_file});
	$model->source("ModelSEED");
	#Creating folder for imported model
	my $folder = $parameters->{output_path}.$parameters->{output_file};
	$self->save_object($folder,undef,"modelfolder");
	my $genome = $model->genome();
	$model->name($genome->scientific_name()." model");
	if (defined($genome->contigset_ref())) {
   		$self->save_object($folder."/contigset",$genome->contigs(),"contigset");
   		#Resetting reference for contigset to local path
   		$genome->contigset_ref("contigset||");
   	}
	#Saving genome inside the model folder - no translation is needed
   	$self->save_object($folder."/genome",$genome,"genome");
	$model->translate_to_localrefs();
	$self->save_object($folder."/gapfilling",undef,"folder");
	#Transfering gapfillings
	my $gfs = $model->gapfillings();
	if (@{$gfs} == 0) {
		Bio::KBase::utilities::log($model->wsmeta()->[2].".".$model->wsmeta()->[0]."/gapfilling");
		my $list = Bio::ModelSEED::patricenv::call_ws("ls",{
			paths => [$model->wsmeta()->[2].".".$model->wsmeta()->[0]."/gapfilling"],
			excludeDirectories => 1,
			excludeObjects => 0,
			recursive => 1,
			query => {type => "fba"}
		});
		if (defined($list->{$model->wsmeta()->[2].".".$model->wsmeta()->[0]."/gapfilling"})) {
			$list = $list->{$model->wsmeta()->[2].".".$model->wsmeta()->[0]."/gapfilling"};
			for (my $i=0; $i < @{$list}; $i++) {
				$model->add("gapfillings",{
					id => $list->[$i]->[0],
					gapfill_id => $list->[$i]->[0],
					fba_ref => $list->[$i]->[2]."/".$list->[$i]->[0]."||",
					integrated => 1,
					integrated_solution => 0,
					media_ref => $list->[$i]->[7]->{media}
				});
			}
			$gfs = $model->gapfillings();
		}
	}
	for (my $i=0; $i < @{$gfs}; $i++) {
		my $fba = $gfs->[$i]->fba();
		if (!defined($fba->gapfillingSolutions()->[0])) {
			$model->remove("gapfillings",$gfs->[$i]);
		} else {
			Bio::KBase::utilities::log("Valid gapfilling:".$parameters->{output_file}."/gapfilling/gf.".$i);
			$fba->fbamodel($model);
			$gfs->[$i]->fba_ref($parameters->{output_file}."/gapfilling/".$fba->id()."||");
			$fba->translate_to_localrefs();			
			#Saving FBA object
			$fba->fbamodel_ref("../../".$model->id()."||");
			$self->save_object($folder."/gapfilling/".$fba->id(),$fba,"fba");
			my $solution = $fba->gapfillingSolutions()->[0];
			#Integrating new reactions into model
			my $rxns = $solution->gapfillingSolutionReactions();
			for (my $i=0; $i < @{$rxns}; $i++) {
				my $rxn = $rxns->[$i];
				my $rxnid = $rxn->reaction()->id();
				my $mdlrxn;
				my $ismdlrxn = 0;
				$mdlrxn = $model->getObject("modelreactions",$rxnid.$rxn->compartmentIndex());
				if (!defined($mdlrxn)) {
					Bio::KBase::utilities::log("Could not find ".$rxnid." in model ".$parameters->{output_file});
					$mdlrxn = $model->addModelReaction({
						reaction => $rxn->reaction()->msid(),
						compartment => $rxn->reaction()->templatecompartment()->id(),
						compartmentIndex => $rxn->compartmentIndex(),
						direction => $rxn->direction()
					});
					$mdlrxn->gapfill_data()->{$fba->id()} = "added:".$rxn->direction();
				} else {
					my $prots = $mdlrxn->modelReactionProteins();
					if (@{$prots} == 0) {
						$mdlrxn->gapfill_data()->{$fba->id()} = "added:".$rxn->direction();
					} else {
						$mdlrxn->direction("=");
						$mdlrxn->gapfill_data()->{$fba->id()} = "reversed:".$rxn->direction();
					}
				}
			}
		}
	}
	$model->genome_ref($model->id()."/genome||");
	$self->save_object($parameters->{output_path}.$parameters->{output_file},$model,"model",{});
	return {
		fbamodel_ref => $parameters->{output_path}.$parameters->{output_file},
		report_ref => $parameters->{output_path}.$parameters->{output_file}."/jobresult"
	};
}

sub load_to_shock {
	my($self,$data) = @_;
	my $uuid = Data::UUID->new()->create_str();
	File::Path::mkpath Bio::KBase::utilities::conf("ModelSEED","fbajobdir");
	my $filename = Bio::KBase::utilities::conf("ModelSEED","fbajobdir").$uuid;
	Bio::KBase::ObjectAPI::utilities::PRINTFILE($filename,[$data]);
	my $output = Bio::KBase::ObjectAPI::utilities::runexecutable("curl -H \"Authorization: OAuth ".Bio::KBase::utilities::token()."\" -X POST -F 'upload=\@".$filename."' ".Bio::KBase::utilities::conf("ProbModelSEED","shock-url")."/node");
	$output = Bio::KBase::ObjectAPI::utilities::FROMJSON(join("\n",@{$output}));
	return Bio::KBase::utilities::conf("ProbModelSEED","shock-url")."/node/".$output->{data}->{id};
}

#****************************************************************************
#Constructor
#****************************************************************************
sub new {
	my($class, $parameters) = @_;
	my $self = {};
	bless $self, $class;
	$parameters = Bio::KBase::utilities::args($parameters,[],{
		token => undef,
		username => undef,
		setowner => undef,
		adminmode => 0,
		method => "unknown",
		configfile => $ENV{KB_DEPLOYMENT_CONFIG},
		configservice => "ProbModelSEED",
		workspace_url => undef,
		call_context => undef,
		parameters => {}
	});
	if (defined($parameters->{token}) && defined($parameters->{username})) {
		$parameters->{call_context} = Bio::KBase::utilities::create_context({
			token => $parameters->{token},
			user => $parameters->{username},
			method => $parameters->{method},
			provenance => []
		});
	}
	if (!defined(Bio::KBase::utilities::config_hash())) {
		Bio::KBase::utilities::read_config({
			filename => $parameters->{configfile},
			service => $parameters->{configservice},
		});
	}
	Bio::ModelSEED::patricenv::initialize_call($parameters->{call_context},$parameters->{method},$parameters->{parameters},undef);
	Bio::KBase::utilities::setconf("ProbModelSEED","adminmode",$parameters->{adminmode});
	if (defined($parameters->{workspace_url})) {
		Bio::KBase::utilities::setconf("ProbModelSEED","workspace-url",$parameters->{workspace_url});
	} else {
		Bio::KBase::utilities::setconf("ProbModelSEED","workspace-url",Bio::KBase::utilities::conf("ProbModelSEED","default-workspace-url"));
	}
	if (defined($parameters->{setowner})) {
		Bio::KBase::utilities::setconf("ProbModelSEED","setowner",$parameters->{setowner});
	} else {
		Bio::KBase::utilities::setconf("ProbModelSEED","setowner","");
	}
	$self->run_server_checks();
	Bio::KBase::utilities::set_handler($self);
	Bio::KBase::ObjectAPI::functions::set_handler($self);
	return $self;
}

1;
