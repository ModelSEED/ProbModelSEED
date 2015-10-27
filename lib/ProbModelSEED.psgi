use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl;

use Bio::ModelSEED::ProbModelSEED::Service;
use Plack::Middleware::CrossOrigin;



my @dispatch;

{
    my $obj = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl->new;
    push(@dispatch, 'ProbModelSEED' => $obj);
}


my $server = Bio::ModelSEED::ProbModelSEED::Service->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $handler = sub { $server->handle_input(@_) };

$handler = Plack::Middleware::CrossOrigin->wrap( $handler, origins => "*", headers => "*");
