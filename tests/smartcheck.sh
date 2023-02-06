#!/usr/bin/env bats

setup() {
  . $PGPATH/bin/deploy-smartcheck.sh test
}

@test "deploy smartcheck | expect service(s) available" {
  run main
  [ "$status" -eq 0 ]
}

@test "deployments smartcheck | expect count of deployments equal count of ready deployments" {
  run test
  [ "$status" -eq 0 ]
  [ "$output" > 0 ]
}

@test "scan with smartcheck | expect completed-with-findings result" {
  run scan
  if [ -z "${output##*completed-with-findings*}" ] ; then
    result=0
  else
    result=1
  fi
  [ "$status" -eq 0 ]
  [ "$result" -eq 0 ]
}