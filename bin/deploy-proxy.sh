#!/bin/bash

set -e

# Source helpers
.  $PGPATH/bin/playground-helpers.sh

# Get config
export SERVICE=$1
SERVICE_NAME="$(yq '.services[] | select(.name==env(SERVICE)) | .proxy_service_name' $PGPATH/config.yaml)"
SERVICE_NAMESPACE="$(yq '.services[] | select(.name==env(SERVICE)) | .namespace' $PGPATH/config.yaml)"
SERVICE_PORT="$(yq '.services[] | select(.name==env(SERVICE)) | .proxy_service_port' $PGPATH/config.yaml)"
LISTEN_PORT="$(yq '.services[] | select(.name==env(SERVICE)) | .proxy_listen_port' $PGPATH/config.yaml)"

#######################################
# Creates the proxy configuration
# for the given service
# Globals:
#   SERVICE_NAMESPACE
#   SERVICE_NAME
#   SERVICE_PORT
#   LISTEN_PORT
# Arguments:
#   None
# Outputs:
#   None
#######################################
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
    cp $PGPATH/templates/passthrough.conf /tmp/passthrough.conf
  fi

  # if grep -Fq "upstream ${SERVICE_NAME} " /tmp/passthrough.conf
  if grep -Fq "upstream ${SERVICE} " /tmp/passthrough.conf
  then
    printf '%s\n' "Proxy already configured for ${SERVICE_NAME}"
    exit 0
  else
    FRAGMENT=$(cat $PGPATH/templates/passthrough-fragment.conf)

    sed -i "s|###|${FRAGMENT}|" /tmp/passthrough.conf

    # sed -i "s|_SERVICE|${SERVICE_NAME}|g" /tmp/passthrough.conf
    sed -i "s|_SERVICE|${SERVICE}|g" /tmp/passthrough.conf
    sed -i "s|_DESTINATION_HOST|${SERVICE_HOST}|" /tmp/passthrough.conf
    sed -i "s|_DESTINATION_PORT|${SERVICE_PORT}|" /tmp/passthrough.conf
    sed -i "s|_LISTEN_PORT|${LISTEN_PORT}|" /tmp/passthrough.conf
    sudo cp /tmp/passthrough.conf /etc/nginx/passthrough.conf
  fi
}

create_proxy_configuration

printf '%s\n' "Remove default site 🍭"
sudo rm -f /etc/nginx/sites-enabled/default
printf '%s\n' "Apply nginx proxy configuration 🍭"
sudo nginx -t
sudo service nginx restart

if is_linux ; then
  echo "Service ${SERVICE} on: http(s)://$(hostname -I | awk '{print $1}'):${LISTEN_PORT}"
fi

unset SERVICE