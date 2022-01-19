#!/usr/bin/env bats

setup() {
  . ./deploy-container-security.sh test
}

@test "delete container-security deployment | expect deployment gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
