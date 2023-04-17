# Add-On: Workload Security

## Deploy

To deploy Workload Security demo environmant run:

```sh
deploy-workload-security.sh
```

It actually does NOT deploy Workload Security but creates a small environment in AWS utilising Terraform. The following resources are created:

- VPC
- Subnet
- Internet Gateway
- Route Table
- Security Group
- EC2 Instances
  - web1
  - web2 (wordpress)
  - db1 (mysql)

The agent is automatically deployed on `web2` and `db1` with the default `Linux Policy` assigned. All instances are Ubuntu t3.medium.

## Access

If you want to sniff around on your newly created little instances connect to it via:

```sh
# web1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_web1)

# web2
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_web2)

# db1
ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip_db1)
```

## Create Findings

To create some findings run

```sh
scripts/create-findings.sh
```

Feel free to have a look on the script above and modify it to your needs.

## Tear Down

Run

```sh
delete-workload-security.sh
```
