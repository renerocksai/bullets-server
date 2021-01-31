#!/usr/bin/env sh
docker save -o bullets-server.docker.tar bullets-server:latest && gzip bullets-server.docker.tar
