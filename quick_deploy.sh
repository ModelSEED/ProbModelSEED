#!/bin/bash
set -e

SERVICE=ProbModelSEED

DEV_CONTAINER=/disks/p3/dev_container
AUTO_DEPLOY_CFG=auto-deploy.cfg


pushd $DEV_CONTAINER
. user-env.sh

pushd modules/$SERVICE

make

popd

perl auto-deploy $AUTO_DEPLOY_CFG -module $SERVICE

set +e
echo "stopping service"
/disks/p3/deployment/services/$SERVICE/stop_service
set -e

sleep 5 

echo "starting service"
/disks/p3/deployment/services/$SERVICE/start_service

sleep 5

pushd modules/$SERVICE

source /disks/p3/deployment/user-env.sh

perl t/client-tests/probmodelseed.t
if [ $? -ne 0 ] ; then
        echo "BUILD ERROR: problem running make test"
        exit 1
fi

