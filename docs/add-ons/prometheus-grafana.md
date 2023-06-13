# Add-On: Prometheus & Grafana

## Deploy

By running `deploy-prometheus-grafana.sh` you'll get a fully functional and preconfigured Prometheus and Grafana instance on the playground.

The following additional scrapers are configured:

- [api-collector](https://github.com/mawinkler/api-collector)
- [Falco](./falco.md)

## Access

Follow the steps for your platform below.

***Linux***

By default, the Prometheus UI is on port 8081, Grafana on port 8080.

Example:

`Prometheus UI on: http://192.168.1.121:8081`

`Grafana UI on: http://192.168.1.121:8080 w/ admin/trendmicro`

***Cloud9***

See: [Access Falco (Cloud9)](./falco.md#access), but use the `proxy_listen_port`s configured in your config.yaml (default: 8080 (grafana) and 8081 (prometheus)) and choose Source Anywhere. Don't forget to check your inbound rules to allow these ports.

Alternatively, you can get the configured port for the service with `cat services`.

Access to the services should then be possible with the public ip of your Cloud9 instance with your configured port(s).

Example:

`Grafana: <http://YOUR-CLOUD9-PUBLIC-IP:8080>`

`Prometheus: <http://YOUR-CLOUD9-PUBLIC-IP:8081>`
