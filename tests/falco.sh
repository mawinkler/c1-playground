#!/usr/bin/env bats

setup() {
  . ./deploy-falco.sh test
}

@test "delete falco deployment | expect deployment gone" {
  run cleanup
  [ "$status" -eq 0 ]
}

@test "deploy falco | expect service(s) available" {
  run main
  [ "$status" -eq 0 ]
}

@test "deployments ready | expect count of deployments equal count of ready deployments" {
  run test
  [ "$status" -eq 0 ]
  [ "$output" > 0 ]
}
