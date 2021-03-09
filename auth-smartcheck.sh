#!/bin/bash

set -e

SC_NAMESPACE="$(jq -r '.smartcheck_namespace' config.json)"
SC_USERNAME="$(jq -r '.smartcheck_username' config.json)"
SC_PASSWORD="$(jq -r '.smartcheck_password' config.json)"
SC_HOSTNAME="$(jq -r '.smartcheck_hostname' config.json)"
SC_REG_USERNAME="$(jq -r '.smartcheck_reg_username' config.json)"
SC_REG_PASSWORD="$(jq -r '.smartcheck_reg_password' config.json)"
SC_REG_HOSTNAME="$(jq -r '.smartcheck_reg_hostname' config.json)"
SC_AC="$(jq -r '.activation_key' config.json)"
OS="$(uname)"


function password_change_linux {
  # initial password change
  
  printf '%s\n' "authenticating to smart check"
  SC_USERID=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                -H "Content-Type: application/json" \
                -H "Api-Version: 2018-05-01" \
                -H "cache-control: no-cache" \
                -d "{\"user\":{\"userid\":\"${SC_USERNAME}\",\"password\":\"${SC_PASSWORD}\"}}" | \
                  jq '.user.id' | tr -d '"'  2>/dev/null)
  SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                    -H "Content-Type: application/json" \
                    -H "Api-Version: 2018-05-01" \
                    -H "cache-control: no-cache" \
                    -d "{\"user\":{\"userid\":\"${SC_USERNAME}\",\"password\":\"${SC_PASSWORD}\"}}" | \
                      jq '.token' | tr -d '"'  2>/dev/null)
}

function password_change_darwin {
  # initial password change
  
  printf '%s\n' "authenticating to smart check"
  SC_USERID=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                -H "Content-Type: application/json" \
                -H "Api-Version: 2018-05-01" \
                -H "cache-control: no-cache" \
                -d "{\"user\":{\"userid\":\"${SC_USERNAME}\",\"password\":\"${SC_PASSWORD}\"}}" | \
                  jq '.user.id' | tr -d '"'  2>/dev/null)
  SC_BEARERTOKEN=$(curl -s -k -X POST https://${SC_HOST}/api/sessions \
                    -H "Content-Type: application/json" \
                    -H "Api-Version: 2018-05-01" \
                    -H "cache-control: no-cache" \
                    -d "{\"user\":{\"userid\":\"${SC_USERNAME}\",\"password\":\"${SC_PASSWORD}\"}}" | \
                      jq '.token' | tr -d '"'  2>/dev/null)
}


if [ "${OS}" == 'Linux' ]; then
  SERVICE_TYPE='LoadBalancer'
fi
if [ "${OS}" == 'Darwin' ]; then
  SERVICE_TYPE='NodePort'
fi

if [ "${OS}" == 'Linux' ]; then
  SC_HOST=$(kubectl get svc -n ${SC_NAMESPACE} proxy \
            -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  password_change_linux
fi
if [ "${OS}" == 'Darwin' ]; then
  SC_HOST="${SC_HOSTNAME}"
  password_change_darwin
fi

echo "copy & paste curlies:"
echo "export SC_HOST=${SC_HOST}"
echo "export SC_USERID=${SC_USERID}"
echo "export SC_BEARERTOKEN=${SC_BEARERTOKEN}"
echo 
echo "return the latest scan id:"
echo 'SCANID=$(curl -s -k -X GET https://${SC_HOST}/api/scans \
        -H "Content-Type: application/json" \
        -H "Api-Version: 2018-05-01" \
        -H "cache-control: no-cache" \
        -H "authorization: Bearer ${SC_BEARERTOKEN}" | \
        jq -r ".scans[0].id")'
echo 
echo "query checklists:"
echo 'curl -s -k -X GET https://${SC_HOST}/api/scans/${SCANID}/checklists \
        -H "Content-Type: application/json" \
        -H "Api-Version: 2018-05-01" \
        -H "cache-control: no-cache" \
        -H "authorization: Bearer ${SC_BEARERTOKEN}"'
