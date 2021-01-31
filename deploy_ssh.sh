#!/usr/bin/env sh
HOST=$1
if [ -z "$1" ] ; then
    echo "Provide host name"
    exit 0
fi

./build_docker.sh
./export-docker-image.sh
scp bullets-server.docker.tar.gz $HOST:
scp run_container.sh $HOST:

