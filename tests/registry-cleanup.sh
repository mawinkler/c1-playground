#!/usr/bin/env bats

setup() {
  . $PGPATH/bin/deploy-registry.sh test
}

@test "delete registry | expect service gone" {
  run cleanup
  [ "$status" -eq 0 ]
}
