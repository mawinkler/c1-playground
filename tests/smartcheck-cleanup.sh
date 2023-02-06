#!/usr/bin/env bats

setup() {
  . $PGPATH/bin/deploy-smartcheck.sh test
}

@test "delete smartcheck deployment | expect deployment gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
