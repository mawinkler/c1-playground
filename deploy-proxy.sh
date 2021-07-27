#!/bin/bash
SERVICE=$1
SERVICE_NAME="$(jq -r --arg SVC $SERVICE '.services[] | select(.name==$SVC) | .proxy_service_name' config.json)"
SERVICE_NAMESPACE="$(jq -r --arg SVC $SERVICE '.services[] | select(.name==$SVC) | .namespace' config.json)"
SERVICE_PORT="$(jq -r --arg SVC $SERVICE '.services[] | select(.name==$SVC) | .proxy_service_port' config.json)"
LISTEN_PORT="$(jq -r --arg SVC $SERVICE '.services[] | select(.name==$SVC) | .proxy_listen_port' config.json)"
OS="$(uname)"

function create_proxy_configuration {

  SERVICE_HOST=''
  while [ "$SERVICE_HOST" == '' ]
  do
    SERVICE_HOST=$(kubectl get svc -n ${SERVICE_NAMESPACE} ${SERVICE_NAME} \
                -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    sleep 2
  done

  # sudo unlink /etc/nginx/sites-enabled/default

  printf '%s\n' "Configure passthrough for ${SERVICE_NAME}"

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
  echo "Service ${SERVICE} on: http://${HOST_IP}:${LISTEN_PORT}"
fi
