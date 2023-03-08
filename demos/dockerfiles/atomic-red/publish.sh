#!/bin/bash
docker build --tag atomic_red_docker:latest .
docker tag atomic_red_docker:latest mawinkler/atomic_red_docker:latest
docker push mawinkler/atomic_red_docker:latest
