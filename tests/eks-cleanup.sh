#!/usr/bin/env bats

setup() {
  . ./clusters/rapid-eks.sh test
}

@test "delete eks cluster | expect cluster gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
