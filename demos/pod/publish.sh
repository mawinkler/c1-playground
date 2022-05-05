#!/bin/bash
DOCKER_USERNAME=mawinkler
docker login
docker build -t ubuntu .
docker tag ubuntu ${DOCKER_USERNAME}/ubuntu:latest
docker push ${DOCKER_USERNAME}/ubuntu:latest