{
	package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests;
	
	use strict;
	use Test::More;
	use Data::Dumper;
	
	sub new {
	    my($class,$auth,$url,$dump,$config) = @_;
	    my $self = {
			testcount => 0,
			dumpoutput => 0,
			auth => $auth,
			url => $url
	    };
	    $ENV{KB_INTERACTIVE} = 1;
	    if (defined($config)) {
	    	$ENV{KB_DEPLOYMENT_CONFIG} = $config;
	    }
	    if (defined($dump)) {
	    	$self->{dumpoutput} = $dump;
	    }
	    if (!defined($url) || $url eq "impl") {
	    	print "Loading server with this config: ".$ENV{KB_DEPLOYMENT_CONFIG}."\n";
	    	require "Bio/ModelSEED/ProbModelSEED/ProbModelSEEDImpl.pm";
	    	$Bio::ModelSEED::ProbModelSEED::Service::CallContext = Bio::ModelSEED::ProbModelSEED::Service::CallContext->new($auth->[0]->{token},"test",$auth->[0]->{username});
	    	$self->{obj} = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl->new();
	    } else {
	    	require "Bio/ModelSEED/ProbModelSEED/ProbModelSEEDClient.pm";
	    	$self->{obj} = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient->new($url,token => $auth->[0]->{token});
	    }
	    return bless $self, $class;
	}
	
	sub test_harness {
		my($self,$function,$parameters) = @_;
		my $output;
		if (defined($parameters)) {
			$output = $self->{obj}->$function($parameters);
		} else {
			$output = $self->{obj}->$function();
		}
		ok defined($output), "Successfully ran $function!";
		if ($self->{dumpoutput}) {
			print "$function output:\n".Data::Dumper->Dump([$output])."\n\n";
		}
		$self->{testcount}++;
		return $output;
	}
	
	sub run_tests {
		my($self) = @_;
		my $output = $self->test_harness("export_media",{
			media => "/chenry/public/modelsupport/media/Carbon-D-Glucose",
			to_shock => 1,
		});
		$output = $self->test_harness("list_models",undef);
		for(my $i=0; $i < @{$output}; $i++) {
			if ($output->[$i]->{ref} eq "/".$self->{auth}->[0]->{username}."/home/models/TestModel") {
				my $output = $self->test_harness("delete_model",{
					model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
				});
			}
			if ($output->[$i]->{ref} eq "/".$self->{auth}->[0]->{username}."/home/models/PubGenomeModel") {
				my $output = $self->test_harness("delete_model",{
					model => "/".$self->{auth}->[0]->{username}."/home/models/PubGenomeModel",
				});
			}
		}
		#$output = $self->test_harness("ModelReconstruction",{
		#	genome => "/".$self->{auth}->[0]->{username}."/genomes/test/.Buchnera_aphidicola/Buchnera_aphidicola.genome",
		#	fulldb => "0",
		#	output_path => "/".$self->{auth}->[0]->{username}."/home/models",
		#	output_file => "TestModel"
		#});
		$output = $self->test_harness("ModelReconstruction",{
			genome => "PATRICSOLR:83333.84",
			fulldb => "0",
			output_path => "/".$self->{auth}->[0]->{username}."/home/models",
			output_file => "PubGenomeModel"
		});
		$output = $self->test_harness("list_models",undef);
		$output = $self->test_harness("list_gapfill_solutions",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel"
		});
		$output = $self->test_harness("list_fba_studies",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel"
		});
		$output = $self->test_harness("list_model_edits",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel"
		});
		$output = $self->test_harness("GapfillModel",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
			integrate_solution => "1",
			media => "/chenry/public/modelsupport/media/Carbon-D-Glucose"
		});
		$output = $self->test_harness("export_model",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
			format => "sbml",
			to_shock => 1
		});
		$output = $self->test_harness("FluxBalanceAnalysis",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
		});
		$output = $self->test_harness("FluxBalanceAnalysis",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
			media => "/chenry/public/modelsupport/media/Carbon-D-Glucose"
		});
		$output = $self->test_harness("list_gapfill_solutions",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel"
		});
		$output = $self->test_harness("manage_gapfill_solutions",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
			commands => {
				"gf.0" => "u"
			}
		});
		$output = $self->test_harness("manage_gapfill_solutions",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
			commands => {
				"gf.0" => "i"
			}
		});
		$output = $self->test_harness("manage_gapfill_solutions",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
			commands => {
				"gf.0" => "d"
			}
		});
		$output = $self->test_harness("list_fba_studies",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel"
		});
		$output = $self->test_harness("delete_fba_studies",{
			model => "/".$self->{auth}->[0]->{username}."/home/models/TestModel",
			fbas => ["fba.0"]
		});
		done_testing($self->{testcount});
	}
}	

{
	package Bio::ModelSEED::ProbModelSEED::Service::CallContext;
	
	use strict;
	
	sub new {
	    my($class,$token,$method,$user) = @_;
	    my $self = {
	        token => $token,
	        method => $method,
	        user_id => $user
	    };
	    return bless $self, $class;
	}
	sub user_id {
		my($self) = @_;
		return $self->{user_id};
	}
	sub token {
		my($self) = @_;
		return $self->{token};
	}
	sub method {
		my($self) = @_;
		return $self->{method};
	}
	sub log_debug {
		my($self,$msg) = @_;
		print STDERR $msg."\n";
	}
}

1;