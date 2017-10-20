#!/usr/bin/perl -w
use strict;
use JSON::XS;
use Bio::KBase::utilities;
use Bio::ModelSEED::patricenv;
#use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDImpl;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient;
use Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper;

$|=1;

Bio::KBase::utilities::read_config({
	service => "ProbModelSEED"
});
Bio::ModelSEED::patricenv::create_context_from_client_config();

my $client = Bio::ModelSEED::ProbModelSEED::ProbModelSEEDClient->new(Bio::KBase::utilities::conf("Scheduler","msurl"),token => Bio::KBase::utilities::token());
my $jobs = $client->ManageJobs({
		jobs => [53283],
		action => "finish",
		errors => {53283 => 'keys on reference is experimental at /disks/p3dev2/deployment/lib/Bio/KBase/ObjectAPI/functions.pm line 1735.
Use of uninitialized value in concatenation (.) or string at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2079.
Use of uninitialized value in -d at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2080.
Use of uninitialized value in concatenation (.) or string at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2083.
Use of uninitialized value in concatenation (.) or string at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2083.
Use of uninitialized value in concatenation (.) or string at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2098.
Use of uninitialized value in concatenation (.) or string at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2114.
Use of uninitialized value in numeric ne (!=) at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2281.
Use of uninitialized value $ref in pattern match (m//) at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2200.
Use of uninitialized value $ref in pattern match (m//) at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2203.
Use of uninitialized value in concatenation (.) or string at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2114.
Error resetting job status:
encountered object ERROR{Username not found!}ERROR

Trace begun at /vol/model-prod/kbase/deploy/../MSSeedSupportServer/lib/Bio/ModelSEED/MSSeedSupportServer/MSSeedSupportImpl.pm line 171
Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportImpl::_error(Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportImpl=HASH(0x2230e748), Username not found!) called at /vol/model-prod/kbase/deploy/../MSSeedSupportServer/lib/Bio/ModelSEED/MSSeedSupportServer/MSSeedSupportImpl.pm line 180
Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportImpl::get_user_object(Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportImpl=HASH(0x2230e748), login, 13902856r) called at /vol/model-prod/kbase/deploy/../MSSeedSupportServer/lib/Bio/ModelSEED/MSSeedSupportServer/MSSeedSupportImpl.pm line 931
Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportImpl::getRastGenomeData(Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportImpl=HASH(0x2230e748), HASH(0x22670548)) called at /vol/model-prod/kbase/deploy/../MSSeedSupportServer/lib/Bio/ModelSEED/MSSeedSupportServer/Server.pm line 300
eval {...} at /vol/model-prod/kbase/deploy/../MSSeedSupportServer/lib/Bio/ModelSEED/MSSeedSupportServer/Server.pm line 292
Bio::ModelSEED::MSSeedSupportServer::Server::call_method(Bio::ModelSEED::MSSeedSupportServer::Server=HASH(0x22327728), HASH(0x226a9c90), HASH(0x22556848)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/RPC/Any/Server.pm line 33
eval {...} at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/RPC/Any/Server.pm line 26
RPC::Any::Server::handle_input(Bio::ModelSEED::MSSeedSupportServer::Server=HASH(0x22327728), HASH(0x226a9b10)) called at /vol/model-prod/kbase/deploy/bin/../../MSSeedSupportServer/lib/MSSeedSupportServer.psgi line 20
Plack::Sandbox::_2fvol_2fmodel_2dprod_2fkbase_2fdeploy_2fbin_2f_2e_2e_2f_2e_2e_2fMSSeedSupportServer_2flib_2fMSSeedSupportServer_2epsgi::__ANON__(HASH(0x226a9b10)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Plack/Middleware/CrossOrigin.pm line 115
Plack::Middleware::CrossOrigin::call(Plack::Middleware::CrossOrigin=HASH(0x2230d720), HASH(0x226a9b10)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Plack/Component.pm line 50
Plack::Component::__ANON__(HASH(0x226a9b10)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Plack/Util.pm line 165
eval {...} at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Plack/Util.pm line 165
Plack::Util::run_app(CODE(0x223276c8), HASH(0x226a9b10)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Starman/Server.pm line 223
Starman::Server::process_request(Starman::Server=HASH(0x1f6d9e78)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Net/Server.pm line 141
Net::Server::run_client_connection(Starman::Server=HASH(0x1f6d9e78)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Net/Server/PreFork.pm line 273
eval {...} at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Net/Server/PreFork.pm line 273
Net::Server::PreFork::run_child(Starman::Server=HASH(0x1f6d9e78)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Net/Server/PreFork.pm line 229
Net::Server::PreFork::run_n_children(Starman::Server=HASH(0x1f6d9e78), 1) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Net/Server/PreFork.pm line 447
Net::Server::PreFork::coordinate_children(Starman::Server=HASH(0x1f6d9e78)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Net/Server/PreFork.pm line 401
Net::Server::PreFork::run_parent(Starman::Server=HASH(0x1f6d9e78)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Starman/Server.pm line 104
Starman::Server::run_parent(Starman::Server=HASH(0x1f6d9e78)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Net/Server/PreFork.pm line 147
Net::Server::PreFork::loop(Starman::Server=HASH(0x1f6d9e78)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Net/Server.pm line 116
Net::Server::run(Starman::Server=HASH(0x1f6d9e78), port, ARRAY(0x1fb2e060), host, ARRAY(0x1fb2e0c0), proto, ARRAY(0x1fb2e120), serialize, flock, log_level, 2, min_servers, 5, min_spare_servers, 4, max_spare_servers, 4, max_servers, 5, max_requests, 20, user, 4275, group, 311 311 1043 1048 1049 1050 3025 3262, listen, 1024, leave_children_open_on_hup, 1, no_client_stdout, 1, pid_file, /vol/model-prod/kbase/deploy/bin/../pids/mss-service.pid) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Starman/Server.pm line 61
Starman::Server::run(Starman::Server=HASH(0x1f6d9e78), CODE(0x1f6d9f68), HASH(0x1f6da328)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Plack/Handler/Starman.pm line 18
Plack::Handler::Starman::run(Plack::Handler::Starman=HASH(0x1f6d9ea8), CODE(0x1f6d9f68)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Plack/Loader/Delayed.pm line 20
Plack::Loader::Delayed::run(Plack::Loader::Delayed=HASH(0x1f644ab8), Plack::Handler::Starman=HASH(0x1f6d9ea8)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/lib/perl5/site_perl/5.12.2/Plack/Runner.pm line 263
Plack::Runner::run(Plack::Runner=HASH(0x1f6d0388)) called at /vol/rast-bcr/2010-1124/linux-rhel5-x86_64/bin/starman line 31


Trace begun at /disks/p3dev2/deployment/lib/Bio/ModelSEED/MSSeedSupportServer/MSSeedSupportClient.pm line 205
Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportClient::getRastGenomeData(Bio::ModelSEED::MSSeedSupportServer::MSSeedSupportClient=HASH(0x54dbc28), HASH(0x54db658)) called at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 789
Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper::retrieve_RAST_genome(Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper=HASH(0x5482d70), 561.244) called at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2131
Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper::util_get_object(Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper=HASH(0x5482d70), RAST:/561.244) called at /disks/p3dev2/deployment/lib/Bio/KBase/ObjectAPI/functions.pm line 322
Bio::KBase::ObjectAPI::functions::func_build_metabolic_model(HASH(0x40e3120), HASH(0x54db7f0)) called at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2298
Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper::ModelReconstruction(Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper=HASH(0x5482d70), HASH(0x40e3120)) called at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDHelper.pm line 2066
Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper::app_harness(Bio::ModelSEED::ProbModelSEED::ProbModelSEEDHelper=HASH(0x5482d70), ModelReconstruction, HASH(0x40e3120)) called at /disks/p3dev2/dev_container/modules/ProbModelSEED/internalScripts/RunProbModelSEEDJob.pl line 45
eval {...} at /disks/p3dev2/dev_container/modules/ProbModelSEED/internalScripts/RunProbModelSEEDJob.pl line 37
, but neither allow_blessed, convert_blessed nor allow_tags settings are enabled (or TO_JSON/FREEZE method missing) at /disks/p3dev2/deployment/lib/Bio/ModelSEED/ProbModelSEED/ProbModelSEEDClient.pm line 6410.'}
});

1;
