#!/usr/bin/env bats

setup() {
  . ./up.sh test
}

@test "start kind cluster | expect service available" {
  run main
  [ "$status" -eq 0 ]
}

@test "deployments ready | expect count of deployments equal count of ready deployments" {
  run test
  [ "$status" -eq 0 ]
  [ "$output" > 0 ]
}
