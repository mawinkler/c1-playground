# Create a simple AWS Sentry Playground

## Create SSH Keypair

```sh
ssh-keygen -f frankfurt-region-key-pair
```

## Terraform

```sh
# plan
terraform plan -out terraform.out

# apply
terraform apply terraform.out
```

## Access the EC2 instance(s)

```sh
ssh -i frankfurt-region-key-pair -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip)
```

## Create Findings

```sh
terraform/scripts/create-findings.sh
```

## Sentry

```sh
# trigger EBS scan in a region
FUNCTION_SPF=$(aws lambda list-functions | jq -r '.Functions[] | select(.FunctionName | contains("-SnapshotProviderFunction-")) | .FunctionName')

aws lambda invoke --function-name $FUNCTION_SPF --cli-binary-format raw-in-base64-out --payload '{}' response.json
```

```json
{
    "StatusCode": 200,
    "ExecutedVersion": "$LATEST"
}
```

Check Cloud One console afterwards.

## Detroy

```sh
# destroy
terraform destroy
```
