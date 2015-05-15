{
	package Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests;
	
	use strict;
	use Test::More;
	use Data::Dumper;
	
	sub new {
	    my($class,$auth,$url,$dump,$config) = @_;
	    my $self = {
			testcount => 5,
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
	    	$Bio::ModelSEED::ProbModelSEED::Service::CallContext = Bio::ModelSEED::ProbModelSEED::Service::CallContext->new($auth->[0]->{token},"test",$auth->[0]->{username});
	    	require "Bio/ModelSEED/ProbModelSEED/ProbModelSEEDImpl.pm";
	    	$self->{obj} = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl->new();
	    } else {
	    	require "Bio/ModelSEED/ProbModelSEED/ProbModelSEEDClient.pm";
	    	$self->{obj} = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient->new($url,token => $auth->[0]->{token});
	    }
	    return bless $self, $class;
	}
	
	sub run_tests {
		my($self) = @_;
		my $output = $self->{obj}->list_gapfill_solutions({
			model => "/chenry/models/TestModel"
		});
		ok defined($output), "Successfully ran list_gapfill_solutions!";
		if ($self->{dumpoutput}) {
			print "list_gapfill_solutions output:\n".Data::Dumper->Dump([$output])."\n\n";
		}
		
		$output = $self->{obj}->manage_gapfill_solutions({
			model => "/chenry/models/TestModel",
			commands => {
				testgapfill2 => "u"
			}
		});
		ok defined($output), "Successfully ran manage_gapfill_solutions!";
		if ($self->{dumpoutput}) {
			print "manage_gapfill_solutions output:\n".Data::Dumper->Dump([$output])."\n\n";
		}
		
		$output = $self->{obj}->manage_gapfill_solutions({
			model => "/chenry/models/TestModel",
			commands => {
				testgapfill2 => "i"
			}
		});
		ok defined($output), "Successfully ran manage_gapfill_solutions!";
		if ($self->{dumpoutput}) {
			print "manage_gapfill_solutions output:\n".Data::Dumper->Dump([$output])."\n\n";
		}
		
		my $output = $self->{obj}->list_fba_studies({
			model => "/chenry/models/TestModel"
		});
		ok defined($output), "Successfully ran list_fba_studies!";
		if ($self->{dumpoutput}) {
			print "list_fba_studies output:\n".Data::Dumper->Dump([$output])."\n\n";
		}
		
		$output = $self->{obj}->delete_fba_studies({
			model => "/chenry/models/TestModel",
			fbas => []
		});
		ok defined($output), "Successfully ran manage_gapfill_solutions!";
		if ($self->{dumpoutput}) {
			print "manage_gapfill_solutions output:\n".Data::Dumper->Dump([$output])."\n\n";
		}
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
}

1;