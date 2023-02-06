#!/usr/bin/env bats

setup() {
  . $PGPATH/bin/deploy-registry.sh test
}

@test "deploy registry | expect service available" {
  run main
  [ "$status" -eq 0 ]
}

@test "login & push registry | expect login & push succeeded" {
  run test
  [ "$status" -eq 0 ]
}
