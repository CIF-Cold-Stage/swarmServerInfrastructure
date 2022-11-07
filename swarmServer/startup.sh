#!/bin/bash

docker swarm leave -f
docker swarm init
export GENIE_ENV=prod
cd /root/swarmServerInfrastructure/swarmServer
bin/server
