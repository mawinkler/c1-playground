#!/bin/bash

printf '%s\n' "Test Kind Cluster"
tests/kind.sh

printf '%s\n' "Test Registry"
tests/registry.sh

printf '%s\n' "Test Falco"
tests/falco.sh
