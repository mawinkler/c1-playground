# Terraform

```sh
# plan
terraform plan -out terraform.out

# apply
terraform apply terraform.out

# destroy
terraform destroy
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

Check UI after 

## Shell Magic

```sh
curl -fsSL https://raw.githubusercontent.com/mawinkler/c1-playground/master/tools/sentry-get-reports.sh | bash

# DATE=2023-02-13
aws s3api list-objects-v2 --bucket "$bucket" --query 'Contents[?contains(LastModified, `'"$DATE"'`)]' > result.json

scripts/create-findings.sh 

ssh -i frankfurt-region-key-pair -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip)
```
