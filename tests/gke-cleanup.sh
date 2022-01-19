#!/usr/bin/env bats

setup() {
  . ./clusters/rapid-gke.sh test
}

@test "delete gke cluster | expect cluster gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
