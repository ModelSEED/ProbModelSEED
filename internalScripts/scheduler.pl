#!/usr/bin/perl -w

########################################################################
# This perl script runs the designated queue for model reconstruction
# Author: Christopher Henry
# Author email: chrisshenry@gmail.com
# Author affiliation: Mathematics and Computer Science Division, Argonne National Lab
# Date of script creation: 10/6/2009
########################################################################
use strict;
use JSON::XS;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient;
#use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl;
use Bio::KBase::utilities;
use Bio::ModelSEED::patricenv;

$|=1;

my $sched = scheduler->new();
$sched->readconfig();
if (!-d $sched->jobdirectory()) {
	mkdir $sched->jobdirectory();
}
if (!-d $sched->jobdirectory()."/jobs/") {
	mkdir $sched->jobdirectory()."/jobs/";
}
if (!-d $sched->jobdirectory()."/errors/") {
	mkdir $sched->jobdirectory()."/errors/";
}
if (!-d $sched->jobdirectory()."/output/") {
	mkdir $sched->jobdirectory()."/output/";
}
if (-e $sched->jobdirectory()."/schedulerPID") {
	unlink($sched->jobdirectory()."/schedulerPID");
}
open(PID, "> ".$sched->jobdirectory()."/schedulerPID") || die "could not open PID file!"; 
print PID "$$\n"; 
close(PID);

$sched->monitor();

#Declaring scheduler package
package scheduler;

sub new {
	my ($class) = @_;
	my $self = {};
    return bless $self;
}

sub directory {
    my ($self) = @_;
	return $self->{_directory};
}

sub client {
    my ($self) = @_;
    if (!defined($self->{_client})) {
    	
    	#$self->{_client} = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl->new();
    	$self->{_client} = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient->new($self->msurl(),token => Bio::KBase::utilities::token());
    }
	return $self->{_client};
}

sub monitor {
    my($self) = @_;
    my $continue = 1;
	while ($continue == 1) {
		my $count = $self->{_threads};
		my $jobs;
		eval {
			my $output = $self->client()->CheckJobs({
				admin => 1,
				scheduler => 1,
				exclude_failed => 1,
				exclude_running => 0,
				exclude_complete => 1,
				exclude_queued => 1,
			});
			foreach my $key (keys(%{$output})) {
				push(@{$jobs},$output->{$key});
			}
		};
		my $runningCount;
		if (defined($jobs)) {
			$runningCount = @{$jobs};
			for (my $i=0; $i < @{$jobs}; $i++) {
				my $job = $jobs->[$i];
				if ($self->check_job_is_running($job) == 0) {
					my $filename = $self->jobdirectory()."/jobs/".$job->{id}."/stderr.log";
					my $error = "";
					if (-e $filename) {
						open (INPUT, "<", $filename);
					    while (my $Line = <INPUT>) {
					        chomp($Line);
					        $Line =~ s/\r//;
							$error .= $Line."\n";
					    }
					    close(INPUT);
					} else {
						$error .= "Job no longer running for unknown reason!";
					}
					eval {
						my $status = $self->client()->ManageJobs({
							jobs => [$job->{id}],
							action => "finish",
							status => "running",
							errors => {
								$job->{id} => $error
							}
						});
					};
					$runningCount--;
				}
			}
			print $runningCount." jobs now running!\n";
		}
		#Queuing new jobs
		my $openSlots = ($count - $runningCount);
		$jobs = [];
		eval {
			my $output = $self->client()->CheckJobs({
				admin => 1,
				exclude_failed => 1,
				exclude_running => 1,
				exclude_complete => 1,
				exclude_queued => 0,
			});
			foreach my $key (keys(%{$output})) {
				push(@{$jobs},$output->{$key});
			}
		};
		print @{$jobs}." jobs with ".$openSlots." open slots!\n";
		if (defined($jobs) && $openSlots > 0) {
			while ($openSlots > 0 && @{$jobs} > 0) {
				my $job = shift(@{$jobs});
				print "Queuing job:".$job->{id}."\n";
				$self->queueJob($job);
				$openSlots--;
			}
		}
		print "Deleting old files...\n";
		$self->clearAllOldFiles();
		print "Sleeping...\n";
		sleep(60);
	}
}
	
sub printJobFile {
	my ($self,$job) = @_;
	$job->{msurl} = $self->msurl();
	delete $job->{_id};
	my $JSON = JSON::XS->new();
    my $data = $JSON->encode($job);
	my $directory = $self->jobdirectory()."/jobs/".$job->{id}."/";
	if (!-d $directory) {
		mkdir $directory;
	}
	if (-e $directory."jobfile.json") {
		unlink $directory."jobfile.json";
	}
	if (-e $directory."pid") {
		unlink $directory."pid";
	}
	open(my $fh, ">", $directory."jobfile.json") || return;
	print $fh $data;
	close($fh);
	return $directory;
}

sub queueJob {
	my ($self,$job) = @_;
	my $jobdir = $self->printJobFile($job);
	my $pid;
	my $executable = $self->{_executable}." ".$job->{id};
	my $cmd = "nohup ".$executable." > ".$jobdir."stdout.log 2> ".$jobdir."stderr.log &";
  	system($cmd);
  	for (my $i=0; $i < 6; $i++) {
  		sleep(5);
  		if (-e $jobdir."pid") {
  			last;	
  		}
  	}
  	if (-e $jobdir."pid") {
	  	open( my $fh, "<", $jobdir."pid");
		$pid = <$fh>;
		close($fh);
		chomp($pid);
		eval {
			my $status = $self->client()->ManageJobs({
				jobs => [$job->{id}],
				action => "start",
				scheduler => 1,
				reports => {
					$job->{id} => $pid
				}
			});
		};
  	} else {
  		eval {
			my $status = $self->client()->ManageJobs({
				jobs => [$job->{id}],
				action => "finish",
				errors => {
					$job->{id} => "Could not assign PID to job!"
				}
			});
		};
  	}
}

sub haltalljobs {
    my($self) = @_;
	my $runningJobs = $self->runningJobs();
	foreach my $key (keys(%{$runningJobs})) {
		system("kill -9 ".$key);		
	}
}

sub readconfig {
    my($self) = @_; 
	Bio::KBase::utilities::read_config({
		service => "Scheduler"
	});
	Bio::ModelSEED::patricenv::create_context_from_client_config({});
	$self->{_jobdirectory} = Bio::KBase::utilities::conf("Scheduler","jobdirectory");
	$self->{_msurl} = Bio::KBase::utilities::conf("Scheduler","msurl");
	$self->{_auth} = Bio::KBase::utilities::token();
	$self->{_threads} = Bio::KBase::utilities::conf("Scheduler","threads");
	$self->{_executable} = Bio::KBase::utilities::conf("Scheduler","executable");
}

sub check_job_is_running {
	my($self,$jobid) = @_;
	system("ps -p ".$jobid->{pid}." > ".$self->jobdirectory()."/jobs/".$jobid->{id}."/ps.out");
	open( my $fh, "<", $self->jobdirectory()."/jobs/".$jobid->{id}."/ps.out");
	my $id = $jobid->{pid};
	while (my $line = <$fh>) {
		if ($line =~ m/$id/) {
			close($fh);
			return 1;
		}
	}
	close($fh);
	return 0;
}

sub msurl {
	 my($self) = @_;
	 return $self->{_msurl};
}

sub jobdirectory {
	 my($self) = @_;
	 return $self->{_jobdirectory};
}

sub script {
	my($self) = @_;
	if ($self->{_executable} =~ m/([^\/]+)$/) {
		return $1;
	}
	return "";
}

sub auth {
	 my($self) = @_;
	 return $self->{_auth};
}

sub clearOldDirectoryFiles {
	my($self,$directory) = @_;
	my $now = time();       # get current time
	my $age = 60*60*24*7;  # convert 7 days into seconds
	my $files = [];
	opendir(DIR,$directory) || die "Can't open $directory : $!\n";
	push(@{$files},readdir(DIR));
	close(DIR);
	foreach my $file (@{$files}) {	
		my @stat = stat($directory."/".$file);
		if ($stat[9] < ($now - $age)) {
			unlink($directory."/".$file);
		}
	}
}

sub clearAllOldFiles {
	my($self) = @_;
	my $directories = [qw(errors output jobs)];
	for (my $i=0; $i < @{$directories}; $i++) {
		$self->clearOldDirectoryFiles($sched->jobdirectory()."/".$directories->[$i]."/");
	}
}

1;
