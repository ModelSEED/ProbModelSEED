use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;
use LWP::UserAgent;

my $ws = Bio::P3::Workspace::ScriptHelpers::wsClient();
my $list = $ws->ls({paths => ["/chenry/public/PATRICModels/"]});

print join(@{$list->{"/chenry/public/PATRICModels/"}->[0]})."\n";

my $directory = $ARGV[0];

#for (my $i=0; $i < @{$list->{"/chenry/public/PATRICModels/"}}; $i++) {
for (my $i=0; $i < 5; $i++) {
	my $current = $list->{"/chenry/public/PATRICModels/"}->[$i]->[0];	
	if (!-e $directory."/".$current.".essentials") {
	    eval {
		    my $output = $ws->get({objects => [$list->{"/chenry/public/PATRICModels/"}->[$i]->[2]."/".$list->{"/chenry/public/PATRICModels/"}->[$i]->[0]."/gapfilling/fba.0.essentials"]});
			if ($output->[0]->[1] =~ m/https:\/\/p3.theseed.org\/services\/shock_api\/node\//) {
				my $ua = LWP::UserAgent->new();
				my $res = $ua->get($output->[0]->[1]."?download",Authorization => "OAuth " . Bio::P3::Workspace::ScriptHelpers::token());
				open(my $fh, ">", $directory."/".$current.".essentials");
				print $fh $res->{_content};
				close ($fh);
			} else {
				open(my $fh, ">", $directory."/".$current.".essentials");
				print $fh $output->[0]->[1];
				close ($fh);
			}
		};
		if ($@) {
		    print "Error:".$current."\n";
		} else {
			print "Success:".$current."\n";
		}
	}
}