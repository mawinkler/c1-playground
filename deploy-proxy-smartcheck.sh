#!/bin/bash

SERVICE_NAME="$(jq -r '.smartcheck_proxy_service_name' config.json)"
SERVICE_NAMESPACE="$(jq -r '.smartcheck_namespace' config.json)"
SERVICE_PORT="$(jq -r '.smartcheck_proxy_service_port' config.json)"
LISTEN_PORT="$(jq -r '.smartcheck_proxy_listen_port' config.json)"
USERNAME="$(jq -r '.smartcheck_username' config.json)"
PASSWORD="$(jq -r '.smartcheck_password' config.json)"
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

  LINE="include /etc/nginx/passthrough.conf;"
  FILE='/etc/nginx/nginx.conf'
  grep -qF -- "$LINE" "$FILE" || echo ${LINE} | sudo tee -a ${FILE}

  if [ ! -f /tmp/passthrough.conf ]; then
    cp templates/passthrough.conf /tmp/passthrough.conf
  fi
  FRAGMENT=$(cat templates/passthrough-fragment.conf)

  sed -i "s|###|${FRAGMENT}|" /tmp/passthrough.conf

  sed -i "s|_SERVICE|${SERVICE_NAME}|g" /tmp/passthrough.conf
  sed -i "s|_DESTINATION_HOST|${SERVICE_HOST}|" /tmp/passthrough.conf
  sed -i "s|_DESTINATION_PORT|${SERVICE_PORT}|" /tmp/passthrough.conf
  sed -i "s|_LISTEN_PORT|${LISTEN_PORT}|" /tmp/passthrough.conf
  sudo cp /tmp/passthrough.conf /etc/nginx/passthrough.conf
}

create_proxy_configuration

printf '%s\n' "Remove default site 🍭"
sudo rm -f /etc/nginx/sites-enabled/default

printf '%s\n' "Apply nginx proxy configuration 🍭"
sudo nginx -t
sudo service nginx restart

HOST_IP=$(hostname -I | awk '{print $1}')

if [ "${OS}" == 'Linux' ]; then
  echo "Smart check UI on: https://${HOST_IP}:${LISTEN_PORT} w/ ${USERNAME}/${PASSWORD}"
fi
