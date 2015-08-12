use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl;

use Bio::ModelSEED::ProbModelSEED::Service;
use Plack::Middleware::CrossOrigin;
use Plack::Builder;



my @dispatch;

{
    my $obj = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl->new;
    push(@dispatch, 'ProbModelSEED' => $obj);
}


my $server = Bio::ModelSEED::ProbModelSEED::Service->new(instance_dispatch => { @dispatch },
				allow_get => 0,
			       );

my $rpc_handler = sub { $server->handle_input(@_) };

$handler = builder {
    mount "/ping" => sub { $server->ping(@_); };
    mount "/auth_ping" => sub { $server->auth_ping(@_); };
    mount "/" => $rpc_handler;
};

$handler = Plack::Middleware::CrossOrigin->wrap( $handler, origins => "*", headers => "*");
