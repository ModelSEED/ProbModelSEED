use strict;
use Data::Dumper;
use Bio::P3::Workspace::ScriptHelpers;

my $msclient = Bio::P3::Workspace::ScriptHelpers::msClient();

my $output = $msclient->ModelReconstruction({
    genome => "PATRIC:1052588.4",
});

print Data::Dumper->Dump([$output]);