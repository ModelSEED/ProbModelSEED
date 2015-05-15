use FindBin qw($Bin);
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests;

my $tester = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests->new(
	[{
		username => "chenry",
		token => "un=chenry|tokenid=03B0C858-7A70-11E4-9DE6-FDA042A49C03|expiry=1449094224|client_id=chenry|token_type=Bearer|SigningSubject=http://rast.nmpdr.org/goauth/keys/E087E220-F8B1-11E3-9175-BD9D42A49C03|sig=085255b952c8db3ddd7e051ac4a729f719f22e531ddbc0a3edd86a895da851faa93249a7347c75324dc025b977e9ac7c4e02fb4c966ec6003ecf90d3148e35160265dbcdd235658deeed0ec4e0c030efee923fda1a55e8cc6f116bcd632fa6a576d7bf4a794554d2d914b54856e1e7ac2b071f81a8841d142123095f6af957cc"
	}],
	"https://p3.theseed.org/services/ProbModelSEED",
	1,
	$Bin."/../../configs/test.cfg"
);

$tester->run_tests();

done_testing($tester->{testcount});