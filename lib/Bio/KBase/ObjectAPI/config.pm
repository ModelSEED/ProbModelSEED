package Bio::KBase::ObjectAPI::config;
use strict;

our $username = undef;
our $configdir = undef;
our $mfatoolkit_binary = undef;
our $mfatoolkit_job_dir = undef;
our $source = undef;
our $default_biochemistry = undef;
our $FinalJobCache = undef;
our $run_as_app = undef;
our $method = undef;
our $adminmode = undef;
our $shock_url = undef;
our $workspace_url = undef;
our $mssserver_url = undef;
our $appservice_url = undef;
our $template_dir = undef;
our $classifier = undef;
our $cache_targets = undef;
our $file_cache = undef;
our $token = undef;
our $data_api_url = undef;
our $default_media = undef;
our $bin_directory = undef;
our $home_dir = undef;

sub home_dir {
	my $input = shift;
	if (defined($input)) {
		$home_dir = $input;
	}
	return $home_dir;
}

sub bin_directory {
	my $input = shift;
	if (defined($input)) {
		$bin_directory = $input;
	}
	return $bin_directory;
}

sub config_directory {
	my $input = shift;
	if (defined($input)) {
		$configdir = $input;
	}
	return $configdir;
}

sub username {
	my $input = shift;
	if (defined($input)) {
		$username = $input;
	}
	return $username;
}

sub mfatoolkit_binary {
	my $input = shift;
	if (defined($input)) {
		$mfatoolkit_binary = $input;
	}
	return $mfatoolkit_binary;
}

sub mfatoolkit_job_dir {
	my $input = shift;
	if (defined($input)) {
		$mfatoolkit_job_dir = $input;
	}
	return $mfatoolkit_job_dir;
}

sub source {
	my $input = shift;
	if (defined($input)) {
		$source = $input;
	}
	return $source;
}

sub default_biochemistry {
	my $input = shift;
	if (defined($input)) {
		$default_biochemistry = $input;
	}
	return $default_biochemistry;
}

sub FinalJobCache {
	my $input = shift;
	if (defined($input)) {
		$FinalJobCache = $input;
	}
	return $FinalJobCache;
}

sub run_as_app {
	my $input = shift;
	if (defined($input)) {
		$run_as_app = $input;
	}
	return $run_as_app;
}

sub method {
	my $input = shift;
	if (defined($input)) {
		$method = $input;
	}
	return $method;
}

sub adminmode {
	my $input = shift;
	if (defined($input)) {
		$adminmode = $input;
	}
	return $adminmode;
}

sub shock_url {
	my $input = shift;
	if (defined($input)) {
		$shock_url = $input;
	}
	return $shock_url;
}

sub workspace_url {
	my $input = shift;
	if (defined($input)) {
		$workspace_url = $input;
	}
	return $workspace_url;
}

sub mssserver_url {
	my $input = shift;
	if (defined($input)) {
		$mssserver_url = $input;
	}
	return $mssserver_url;
}

sub appservice_url {
	my $input = shift;
	if (defined($input)) {
		$appservice_url = $input;
	}
	return $appservice_url;
}

sub template_dir {
	my $input = shift;
	if (defined($input)) {
		$template_dir = $input;
	}
	return $template_dir;
}

sub classifier {
	my $input = shift;
	if (defined($input)) {
		$classifier = $input;
	}
	return $classifier;
}

sub cache_targets {
	my $input = shift;
	if (defined($input)) {
		$cache_targets = $input;
	}
	return $cache_targets;
}

sub file_cache {
	my $input = shift;
	if (defined($input)) {
		$file_cache = $input;
	}
	return $file_cache;
}

sub token {
	my $input = shift;
	if (defined($input)) {
		$token = $input;
	}
	return $token;
}

sub data_api_url {
	my $input = shift;
	if (defined($input)) {
		$data_api_url = $input;
	}
	return $data_api_url;
}

sub default_media {
	my $input = shift;
	if (defined($input)) {
		$default_media = $input;
	}
	return $default_media;
}

1;
