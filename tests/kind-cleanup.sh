#!/usr/bin/env bats

setup() {
  . ./up.sh test
}

@test "delete kind cluster | expect container gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
