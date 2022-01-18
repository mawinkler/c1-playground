#!/usr/bin/env bats

setup() {
  . ./deploy-registry.sh test
}

@test "delete registry | expect service gone" {
  run cleanup
  [ "$status" -eq 0 ]
}

@test "deploy registry | expect service available" {
  run main
  [ "$status" -eq 0 ]
}

@test "login & push registry | expect login & push succeeded" {
  run test
  [ "$status" -eq 0 ]
}
