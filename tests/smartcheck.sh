#!/usr/bin/env bats

setup() {
  . ./deploy-smartcheck.sh test
}

@test "deploy smartcheck | expect service(s) available" {
  run main
  [ "$status" -eq 0 ]
}

@test "deployments smartcheck | expect count of deployments equal count of ready deployments" {
  run test
  [ "$status" -eq 0 ]
  [ "$output" > 0 ]
}
