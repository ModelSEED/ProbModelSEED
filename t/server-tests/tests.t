use FindBin qw($Bin);
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests;

my $tester = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests->new($bin);
$tester->run_tests();