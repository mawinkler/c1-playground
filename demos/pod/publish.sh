#!/bin/bash
DOCKER_USERNAME=mawinkler
docker login
docker build -t demo-magic .
docker tag demo-magic ${DOCKER_USERNAME}/demo-magic:latest
docker push ${DOCKER_USERNAME}/demo-magic:latest