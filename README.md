Repo for development of the ProbModelSEED service

SERVICE DEPENDENCIES:
typecomp
Workspace

SETUP

1) A workspace server must be up and running at the URL located in config file
2) make
3) if you want to run tests: make test
4) make deploy
5) fill in deploy.cfg and set KB_DEPLOYMENT_CONFIG appropriately
6) $TARGET/services/Workspace/start_service

If the server doesn't start up correctly, check /var/log/syslog 
for debugging information.

RUNNING SERVERS
Dev server on twig: https://p3c.theseed.org/dev1/services/ProbModelSEED
Production server on beech: https://p3.theseed.org/services/ProbModelSEED