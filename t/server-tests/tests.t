use FindBin qw($Bin);
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests;

my $tester = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests->new(
	[{
		username => "reviewer",
		token => "un=reviewer|tokenid=C69E8DDE-0CE0-11E5-85A4-D3BB682E0674|expiry=1465195524|client_id=reviewer|token_type=Bearer|SigningSubject=http://rast.nmpdr.org/goauth/keys/E087E220-F8B1-11E3-9175-BD9D42A49C03|this_is_globus=globus_style_token|sig=35fedec4e9f9b4a5a404c4372f7b1aba3cdc91ce694bd9ce070914a83a84a02b2e94bc7b8a946ff05cc56116cbc4e3b31be3f2edfe1728b1d4de88df50cf2f164d2d0c15c6ea6f72ddec93609749c4c81ff776ccba7b8e93463832dc5d7beaaf26173a25861380bde748e778d993f8495638df3e0a87b07ee29ae6ec69e37b97"
	}],
	"impl",
	1,
	$Bin."/../../configs/test.cfg"
);

$tester->run_tests();