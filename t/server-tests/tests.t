use FindBin qw($Bin);
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests;

my $tester = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests->new(
	[{
		username => "chenry",
		token => "un=chenry@patricbrc.org|tokenid=d72d2f63-6d15-43d4-90f3-e604745ee7aa|expiry=1465758352|client_id=chenry@patricbrc.org|token_type=Bearer|realm=patricbrc.org|SigningSubject=https://user.patricbrc.org/public_key|sig=ccf79a7fd0c15fb46e4fe7421196d441b4d6554b7251166ea7b8eef147691542a5751c7bab6abea333d8398e43d44bf57076e77823f1a23c991442124a828523d19912f73afc651e2ffdf0affc05cdfd3759ef9e4f5e387d8c63e5ea954e689af5f5a0f088cbd5a95037a4c439cbec829242305eb9050d9e3a386bb28f923600"
#		token => "un=chenry|tokenid=C3990F36-0E68-11E5-86C3-D5BB682E0674|expiry=1465363882|client_id=chenry|token_type=Bearer|SigningSubject=http://rast.nmpdr.org/goauth/keys/E087E220-F8B1-11E3-9175-BD9D42A49C03|this_is_globus=globus_style_token|sig=7d9f7c6890fdd869f96af8936400ce332ccec6912d951c3af6cc223436a1649077f3191c4305e051fdb018d8a03ed6fe04cf415c6a32b9e5a5fef9d8b65b4abdf55030012a0ff8544d9aba4304d91d9d1ada07dae6b8360be1b4ce70356ce48beed777fbdc34af33ed5025460927c43190214f4054612942dac220cc6dc459d5"
	}],
	"impl",
	1,
	$Bin."/../../configs/test.cfg"
);

$tester->run_tests();