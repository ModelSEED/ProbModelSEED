use strict;
use Bio::P3::Workspace::ScriptHelpers;
use LWP::UserAgent;
use JSON::XS;

my $ws = Bio::P3::Workspace::ScriptHelpers::wsClient();
my $list = $ws->ls({paths => ["/chenry/public/PATRICModels/"]});

#for (my $i=0; $i < 5; $i++) {
for (my $i=0; $i < @{$list->{"/chenry/public/PATRICModels/"}}; $i++) {	
	eval {
	    my $output = $ws->get({objects => [$list->{"/chenry/public/PATRICModels/"}->[$i]->[2]."/".$list->{"/chenry/public/PATRICModels/"}->[$i]->[0]."/genome"]});
		my $content;
		if ($output->[0]->[1] =~ m/https:\/\/p3.theseed.org\/services\/shock_api\/node\//) {
			my $ua = LWP::UserAgent->new();
			my $res = $ua->get($output->[0]->[1]."?download",Authorization => "OAuth " . Bio::P3::Workspace::ScriptHelpers::token());
			$content = $res->{_content};
		} else {
			$content = $output->[0]->[1];
		}
		my $data = decode_json $content;
		my $features = $data->{features};
		open ( my $fh, ">", "/disks/p3dev2/genomes/".$list->{"/chenry/public/PATRICModels/"}->[$i]->[0].".tsv");
		#open ( my $fh, ">", "/Users/chenry/workspace/genomes/".$list->{"/chenry/public/PATRICModels/"}->[$i]->[0].".tsv");
		print $fh "id\tfunction\tcontig\tstart\tdirection\tstop\n";
		for (my $j=0; $j < @{$features}; $j++) {
			print $fh $features->[$j]->{id}."\t".$features->[$j]->{function}."\t".$features->[$j]->{location}->[0]->[0]."\t".$features->[$j]->{location}->[0]->[1]."\t".$features->[$j]->{location}->[0]->[2]."\t".$features->[$j]->{location}->[0]->[3]."\n";
		}
		close($fh);
	};
}