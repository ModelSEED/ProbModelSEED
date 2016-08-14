use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;
use LWP::UserAgent;

my $ws = Bio::P3::Workspace::ScriptHelpers::wsClient();
my $list = $ws->ls({paths => ["/chenry/public/PATRICCoreModels/"]});

print join(@{$list->{"/chenry/public/PATRICCoreModels/"}->[0]})."\n";

my $directory = $ARGV[0];

print "looping!\n";
for (my $i=0; $i < @{$list->{"/chenry/public/PATRICCoreModels/"}}; $i++) {
#for (my $i=0; $i < 5; $i++) {
	if (!-e $directory."/".$current.".rxntbl") {
		my $current = $list->{"/chenry/public/PATRICCoreModels/"}->[$i]->[0];	
		print $current."\n";
	    eval {
		    my $output = $ws->get({objects => [$list->{"/chenry/public/PATRICCoreModels/"}->[$i]->[2]."/".$list->{"/chenry/public/PATRICCoreModels/"}->[$i]->[0]."/".$list->{"/chenry/public/PATRICCoreModels/"}->[$i]->[0].".rxntbl"]});
			if ($output->[0]->[1] =~ m/https:\/\/p3.theseed.org\/services\/shock_api\/node\//) {
				my $ua = LWP::UserAgent->new();
				my $res = $ua->get($output->[0]->[1]."?download",Authorization => "OAuth " . Bio::P3::Workspace::ScriptHelpers::token());
				open(my $fh, ">", $directory."/".$current.".rxntbl");
				print $fh $res->{_content};
				close ($fh);
			} else {
				open(my $fh, ">", $directory."/".$current.".rxntbl");
				print $fh $output->[0]->[1];
				close ($fh);
			}
		};
		if ($@) {
		    die "Error ".$current.":\n".$@."\n\n";
		}
	}
}