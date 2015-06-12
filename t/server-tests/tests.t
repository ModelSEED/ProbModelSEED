use FindBin qw($Bin);
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests;

my $tester = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDTests->new(
	[{
		username => "chenry",
		token => "un=chenry@patricbrc.org|tokenid=266b1377-23a8-48eb-8ca2-3c246ac015dc|expiry=1465673888|client_id=chenry@patricbrc.org|token_type=Bearer|realm=patricbrc.org|SigningSubject=https://user.patricbrc.org/public_key|sig=a8f1272068cb8f0e81cb91e20f26693962af15541e07c5f4122ad38796ba3526364febbc28f01492ee5bc4e08c73fa64603dd862fc2a990f775f37d6028a58e582b6ec110fea0a5a03aee45b32447ef528e9479d730a1b9fb6a9c8ce8bb82281b1d9650668a74f9d3f0f7a15f2928929281e96486c29524e83739d5cede8dc39"
#		token => "un=chenry|tokenid=C3990F36-0E68-11E5-86C3-D5BB682E0674|expiry=1465363882|client_id=chenry|token_type=Bearer|SigningSubject=http://rast.nmpdr.org/goauth/keys/E087E220-F8B1-11E3-9175-BD9D42A49C03|this_is_globus=globus_style_token|sig=7d9f7c6890fdd869f96af8936400ce332ccec6912d951c3af6cc223436a1649077f3191c4305e051fdb018d8a03ed6fe04cf415c6a32b9e5a5fef9d8b65b4abdf55030012a0ff8544d9aba4304d91d9d1ada07dae6b8360be1b4ce70356ce48beed777fbdc34af33ed5025460927c43190214f4054612942dac220cc6dc459d5"
	}],
	"impl",
	1,
	$Bin."/../../configs/test.cfg"
);

$tester->run_tests();