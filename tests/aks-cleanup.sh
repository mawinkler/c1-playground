#!/usr/bin/env bats

setup() {
  . ./clusters/rapid-aks.sh test
}

@test "delete aks cluster | expect cluster gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
