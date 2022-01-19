#!/usr/bin/env bats

setup() {
  . ./deploy-registry.sh test
}

@test "delete registry | expect service gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
