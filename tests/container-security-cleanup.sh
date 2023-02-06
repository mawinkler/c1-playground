#!/usr/bin/env bats

setup() {
  . $PGPATH/bin/deploy-container-security.sh test
}

@test "delete container-security deployment | expect deployment gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
