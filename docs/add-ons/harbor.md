# Add-On: Harbor

## Deploy

> ***Note:*** Harbor deployment is currently only supported for local Ubuntu Playgrounds.

To deploy Harbor run:

```sh
deploy-harbor.sh
```

## Access

Follow the steps for your platform below. A file called `services` is either created or updated with the link and the credentials to connect to Harbor.

***Linux***

Example:

`Service harbor on: https://192.168.1.121:8085 w/ admin/trendmicro`

## Integrate Harbor to Smart Check

Add the Harbor registry as a Generic Registry. On the local Playground the IP address should be 172.250.255.5, port is 443.

Before doing the integration you need to add a user to harbor with admin privileges (`Administration --> User`) and add this user to the available projects as a member.
