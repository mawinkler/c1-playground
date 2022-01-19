#!/usr/bin/env bats

setup() {
  . ./deploy-falco.sh test
}

@test "delete falco deployment | expect deployment gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
