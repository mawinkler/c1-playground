#!/bin/bash

SERVICE_NAME="$(jq -r '.proxy_service_name' config.json)"
SERVICE_NAMESPACE="$(jq -r '.smartcheck_namespace' config.json)"
SERVICE_PORT="$(jq -r '.proxy_service_port' config.json)"
LISTEN_PORT="$(jq -r '.proxy_listen_port' config.json)"
SC_USERNAME="$(jq -r '.smartcheck_username' config.json)"
SC_PASSWORD="$(jq -r '.smartcheck_password' config.json)"
OS="$(uname)"

function create_proxy_configuration {

  SERVICE_HOST=''
  while [ "$SERVICE_HOST" == '' ]
  do
    SERVICE_HOST=$(kubectl get svc -n ${SERVICE_NAMESPACE} proxy \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    sleep 2
  done

  # sudo unlink /etc/nginx/sites-enabled/default

  printf '%s\n' "Configure ssl passthrough for ${SERVICE_NAME}"

  LINE="include /etc/nginx/passthrough-${SERVICE_NAME}.conf;"
  FILE='/etc/nginx/nginx.conf'
  grep -qF -- "$LINE" "$FILE" || echo ${LINE} | sudo tee -a ${FILE}

  cp templates/passthrough.conf /tmp/passthrough-${SERVICE_NAME}.conf
  sed -i "s|_SERVICE|${SERVICE_NAME}|" /tmp/passthrough-${SERVICE_NAME}.conf
  sed -i "s|_DESTINATION_HOST|${SERVICE_HOST}|" /tmp/passthrough-${SERVICE_NAME}.conf
  sed -i "s|_DESTINATION_PORT|${SERVICE_PORT}|" /tmp/passthrough-${SERVICE_NAME}.conf
  sed -i "s|_LISTEN_PORT|${LISTEN_PORT}|" /tmp/passthrough-${SERVICE_NAME}.conf
  sudo cp /tmp/passthrough-smartcheck.conf /etc/nginx/passthrough-${SERVICE_NAME}.conf
}

create_proxy_configuration

printf '%s\n' "Apply nginx proxy configuration 🍭"
sudo nginx -t
sudo service nginx restart

HOST_IP=$(hostname -I | awk '{print $1}')

if [ "${OS}" == 'Linux' ]; then
  echo "Smart check UI on: https://${HOST_IP}:${LISTEN_PORT} w/ ${SC_USERNAME}/${SC_PASSWORD}"
fi
