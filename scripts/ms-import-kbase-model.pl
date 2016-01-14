use strict;
use Bio::P3::Workspace::ScriptHelpers;
use Bio::KBase::AppService::Client;
use Term::ReadKey;

my($opt, $usage) = Bio::P3::Workspace::ScriptHelpers::options("%c %o <kbase model> <kbase username>",[
	["outputpath|p=s", "Destination path for imported model"],
	["outputname|n=s", "Destination name for imported model"],
	["password=s", "KBase password"],
	["kbwsurl|w=s","KBase workspace URL"]
]);
if (!defined($ARGV[0]) || !defined($ARGV[1])) {
	print $usage."\n";
	exit();
}
my $client = Bio::P3::Workspace::ScriptHelpers::msClient();
my $array = [split(/\//,$ARGV[0])];
my $kbws = $array->[0];
my $kbid = $array->[1];
my $input = {
	kbws => $kbws,
	kbid => $kbid,
	kbuser => $ARGV[1],
	kbpassword => $opt->{password},
};
if (defined($opt->{password})) {
	$input->{kbpassword} = $opt->{password};
}
if (!defined($input->{kbpassword})) {
	$input->{kbpassword} = get_pass();
}
if (defined($opt->{kbwsurl})) {
	$input->{kbwsurl} = $opt->{kbwsurl};
}
if (defined($opt->{outputname})) {
	$input->{output_file} = $opt->{outputname};
}
if (defined($opt->{outputpath})) {
	my $paths = Bio::P3::Workspace::ScriptHelpers::process_paths([$opt->{outputpath}]);
	$input->{output_path} = $paths->[0];
}
my $output = $client->ImportKBaseModel($input);
my $JSON = JSON->new->utf8(1);
if ($opt->{pretty} == 1) {
	$JSON->pretty(1);
}
print $JSON->encode([$output]);

sub get_pass {
    my $key  = 0;
    my $pass = ""; 
    print "Password: ";
    ReadMode(4);
    while ( ord($key = ReadKey(0)) != 10 ) {
        # While Enter has not been pressed
        if (ord($key) == 127 || ord($key) == 8) {
            chop $pass;
            print "\b \b";
        } elsif (ord($key) < 32) {
            # Do nothing with control chars
        } else {
            $pass .= $key;
            print "*";
        }
    }
    ReadMode(0);
    print "\n";
    return $pass;
}
