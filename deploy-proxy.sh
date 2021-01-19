#!/bin/bash

printf '%s' "query smart check load balancer ip"

SERVICE_NAME="$(jq -r '.proxy_service_name' config.json)"
SERVICE_NAMESPACE="$(jq -r '.smartcheck_namespace' config.json)"
SERVICE_PORT="$(jq -r '.proxy_service_port' config.json)"
LISTEN_PORT="$(jq -r '.proxy_listen_port' config.json)"

SERVICE_HOST=''
while [ "$SERVICE_HOST" == '' ]
do
  SERVICE_HOST=$(kubectl get svc -n ${SERVICE_NAMESPACE} proxy \
              -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  sleep 2
done

printf ' %s\n' "${SERVICE_HOST}"

# sudo unlink /etc/nginx/sites-enabled/default

printf '%s\n' "configure ssl passthrough for ${SERVICE_NAME}"

LINE="include /etc/nginx/passthrough-${SERVICE_NAME}.conf;"
FILE='/etc/nginx/nginx.conf'
grep -qF -- "$LINE" "$FILE" || echo ${LINE} | sudo tee -a ${FILE}

cp templates/passthrough.conf /tmp/passthrough-${SERVICE_NAME}.conf
sed -i "s|_SERVICE|${SERVICE_NAME}|" /tmp/passthrough-${SERVICE_NAME}.conf
sed -i "s|_DESTINATION_HOST|${SERVICE_HOST}|" /tmp/passthrough-${SERVICE_NAME}.conf
sed -i "s|_DESTINATION_PORT|${SERVICE_PORT}|" /tmp/passthrough-${SERVICE_NAME}.conf
sed -i "s|_LISTEN_PORT|${LISTEN_PORT}|" /tmp/passthrough-${SERVICE_NAME}.conf
sudo cp /tmp/passthrough-smartcheck.conf /etc/nginx/passthrough-${SERVICE_NAME}.conf

# printf '%s' "Get Registry load balancer IP"

# SERVICE_NAME=registry
# SERVICE_NAMESPACE=default
# SERVICE_PORT=5000
# LISTEN_PORT=5001
# SERVICE_HOST=''

# while [ "$SERVICE_HOST" == '' ]
# do
#   SERVICE_HOST=$(kubectl get svc -n ${SERVICE_NAMESPACE} registry2 \
#               -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
#   printf '%s' "."
#   sleep 2
# done

# printf ' - %s\n' "${SERVICE_HOST}"

# # sudo unlink /etc/nginx/sites-enabled/default

# printf '%s\n' "Configure SSL passthrough for ${SERVICE_NAME}"

# LINE="include /etc/nginx/passthrough-${SERVICE_NAME}.conf;"
# FILE='/etc/nginx/nginx.conf'
# grep -qF -- "$LINE" "$FILE" || echo ${LINE} | sudo tee -a ${FILE}

# cp templates/passthrough.conf /tmp/passthrough-${SERVICE_NAME}.conf
# sed -i "s|_SERVICE|${SERVICE_NAME}|" /tmp/passthrough-${SERVICE_NAME}.conf
# sed -i "s|_DESTINATION_HOST|${SERVICE_HOST}|" /tmp/passthrough-${SERVICE_NAME}.conf
# sed -i "s|_DESTINATION_PORT|${SERVICE_PORT}|" /tmp/passthrough-${SERVICE_NAME}.conf
# sed -i "s|_LISTEN_PORT|${LISTEN_PORT}|" /tmp/passthrough-${SERVICE_NAME}.conf
# sudo cp /tmp/passthrough-smartcheck.conf /etc/nginx/passthrough-${SERVICE_NAME}.conf

printf '%s\n' "restart nginx proxy"
sudo nginx -t
sudo service nginx restart
