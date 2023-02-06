#!/usr/bin/env bats

setup() {
  . $PGPATH/bin/deploy-container-security.sh test
}

@test "deploy container-security | expect service(s) available" {
  run main
  [ "$status" -eq 0 ]
}

@test "deployments container-security | expect count of deployments equal count of ready deployments" {
  run test
  [ "$status" -eq 0 ]
  [ "$output" > 0 ]
}
