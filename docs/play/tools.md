# Tools & Scripts

## Disclaimer

All the scripts and tools described here are at a proof-of-concept level. Some finetuning for production use is advised. Additionally, they might not be officially supported by the Cloud One solutions :-).

## Cloud One Sentry

Within the `tools` directory are some scripts for Sentry:

1. `sentry-get-reports` - Downloads all Sentry reports generated within the last 24hs to your local directory
2. `sentry-get-logs` - Downloads all Sentry logs generated within the last 24hs to your local directory
3. `sentry-get-cloudwatch-logs` - Downloads Sentry CloudWatch logs for AM, IM, Parse Volume and Reports
4. `sentry-trigger-ebs-scan` - Trigger a full scan for a given EC2 instance with one or more EBS volumes attached
5. `sentry-trigger-ecr-scan` - Trigger a full scan for a given ECR repo
6. `sentry-trigger-ebs-scan` - Trigger a full scan for a given Lambda
7. `sentry-remove-snapshots` - Delete snapshots created by `sentry-trigger-ebs-scan`

### Script `sentry-get-reports`

The script is region-aware. This means unless you specify it the currently active AWS region from your shell will be used to query the reports.

Example calls:

```sh
# Help
sentry-get-reports help
```

```sh
Usage: [REGION=<aws-region>] sentry-get-reports

Example:
  REGION=eu-central-1 sentry-get-reports
```

```sh
# Get the reports from the current region
sentry-get-reports

# Get the reports from a region other than your current region
REGION=us-east-1 sentry-get-reports
```

Example result:

```sh
sentry-reports-2023-02-13_15-42-54
├── aws-ebs-volumes
│   ├── i-0076dab31026905f5.json
│   ├── i-03c03a975195bf87b.json
│   └── i-08a345a13318f7db0.json
├── aws-ecr-images
│   ├── 634503960501.dkr.ecr.eu-central-1.amazonaws.com_busybox:latest.json
│   ├── 634503960501.dkr.ecr.eu-central-1.amazonaws.com_hello-world:latest.json
│   ├── 634503960501.dkr.ecr.eu-central-1.amazonaws.com_mawinkler_evil:latest.json
│   ├── 634503960501.dkr.ecr.eu-central-1.amazonaws.com_nginx:1.21.6.json
│   └── 634503960501.dkr.ecr.eu-central-1.amazonaws.com_serverless-webhook:latest.json
└── aws-lambda-functions
    ├── CloudOneWorkloadSecurityUS1SNSPublish.json
    ├── Scanner-TM-FileStorageSecu-CreateLambdaAliasLambda-UPdmsJoha1xM.json
    ├── Scanner-TM-FileStorageSecurity-GetLambdaLastConfig-Uj2V8nohPYhb.json
    ├── Scanner-TM-FileStorageSecurity-ScannerLambda-mEoyirF86l1J.json
    ├── Scanner-TM-FileStorageSecu-ScannerDeadLetterLambda-ftXbhuqoFN2b.json
    ├── ScheduledScan-TM-FileStorageSecurit-BucketFullScan-gq0psizTvl7R.json
    ├── ScheduledScan-TM-FileStorageSecurit-BucketFullScan-MyKEV22XwkY6.json
    ├── SecurityHubStack-CreateIntegrationFunctionB363DF0B-Jz2BcKzj5NvD.json
    ├── serverless-webhook.json
    ├── StackSet-SentryStackSet-f8a28bbb-a354-4-sideScanAM-LC9XncBvNApb.json
    ├── StackSet-SentryStackSet-f8a28bbb-a354-4-sideScanIM-xImAvOBHiHRx.json
    ├── StackSet-SentryStackSet-f8a28bbb-a3-sideScanReport-t3DwsQNXYVoj.json
    ├── StackSet-SentryStackSet-f8a28b-ScanInvokerFunction-NnmdRDpmPbH1.json
    ├── StackSet-SentryStackSet-f8a28b-sideScanParseVolume-8Ya9840jWIuv.json
    ├── StackSet-SentryStackSet-f8a2-LambdaUpdaterFunction-HZpcwfJXwNTb.json
    ├── StackSet-SentryStackSet-f8a-SendScanReportFunction-2X3KHz69ulrV.json
    ├── StackSet-SentryStackSet-f8-ScanSQSConsumerFunction-Y24t3VpgJ4eG.json
    ├── StackSet-SentryStackSet-f-deleteEbsSnapshotFunctio-YsSJWo4pwcOP.json
    ├── StackSet-SentryStackSet-f-ecrResourceProviderFunct-sL0O6KdHpsWK.json
    ├── StackSet-SentryStackSet-f-lambdaResourceProviderFu-VdfrMST0mtXQ.json
    ├── StackSet-SentryStackSet-f-snapshotDistributionFunc-s1faGUTYT8sd.json
    ├── StackSet-SentryStackSet-f-SnapshotProviderFunction-07HwDBE41qO0.json
    ├── Storage-TM-FileStorageSec-SetupBucketNotificationL-IMPZcIjLGFTj.json
    ├── Storage-TM-FileStorageSec-SetupBucketNotificationL-R8mg71T8Qj7V.json
    ├── Storage-TM-FileStorageSecu-CreateLambdaAliasLambda-bSaQH7juC9ZV.json
    ├── Storage-TM-FileStorageSecu-CreateLambdaAliasLambda-zkG5ey8gSFje.json
    ├── Storage-TM-FileStorageSecu-PostScanActionTagLambda-5IMogaWAeCBy.json
    ├── Storage-TM-FileStorageSecu-PostScanActionTagLambda-B5cdL2YrPbk0.json
    ├── Storage-TM-FileStorageSecurit-BucketListenerLambda-a2bmnXZRLzxw.json
    ├── Storage-TM-FileStorageSecurit-BucketListenerLambda-C48dmTDLXKBK.json
    └── Storage-TM-FileStorageSecurity_ScanSendEmail.json
```

### Script `sentry-get-logs`

The script is region-aware. This means unless you specify it the currently active AWS region from your shell will be used to query the logs.

Example calls:

```sh
# Help
sentry-get-logs help
```

```sh
Usage: [REGION=<aws-region>] sentry-get-logs

Example:
  REGION=eu-central-1 sentry-get-logs
```

```sh
# Get the logs from the current region
sentry-get-logs

# Get the logs from a region other than your current region
REGION=us-east-1 sentry-get-logs
```

Example result:

```sh
sentry-logs-2023-03-06_14-47-57
└── sentry-sentry-logs-2023-03-06_14-47-57.log
```

### Script `sentry-get-cloudwatch-logs`

Example calls:

```sh
# Help
sentry-get-cloudwatch-logs help
```

```sh
Usage: [RELATIVETIME=<relative time>] [REGION=<aws-region>] sentry-get-cloudwatch-logs

Example:
  RELATIVETIME=30m REGION=eu-central-1 sentry-get-cloudwatch-logs
```

```sh
# Get the logs from the past hour from the current region
sentry-get-cloudwatch-logs

# Get the logs from the past 30 minutes from a region other than your current region
RELATIVETIME=30m REGION=us-east-1 sentry-get-cloudwatch-logs
```

Example result:

```sh
sentry-cloudwatch-logs-2023-03-07_10-18-57
├── sideScanAM.log
├── sideScanIM.log
├── sideScanPV.log
└── sideScanRE.log
```

### Script `sentry-trigger-ebs-scan`

The script is region-aware. This means unless you specify it the currently active AWS region from your shell will be used.

Example calls:

```sh
# Help
sentry-trigger-ebs-scan help
```

```sh
Please specify at least the ec2 instance to be scanned.

Usage: INSTANCE=<instance-id> [REGION=<aws-region>] [USERNAME=<username-tag>] sentry-trigger-ebs-scan

Example:
  INSTANCE=i-0076dab31026905f5 sentry-trigger-ebs-scan
```

If you specify a `USERNAME` the snapshot(s) will be tagged accordingly. This should ease identifying your own snapshots if using a shared account. Default username is `cnctraining`.

```sh
# Trigger scan of EC2 instance i-0076dab31026905f5 existing in the current region
INSTANCE=i-0076dab31026905f5 sentry-trigger-ebs-scan
```

Example result:

```sh
Using region eu-central-1 for user cnctraining
State machine is arn:aws:states:eu-central-1:634503960501:stateMachine:ScannerStateMachine-pueSSKvfdN4K
Instance volume(s)\nvol-03b25f8105caf9f00
Snapshot snap-0f4cc9d1d8a094861 for volume vol-03b25f8105caf9f00 created
{
  "ScanID": "634503960501-635658bd-0deb-42a7-8594-1089d87bfc40",
  "ResourceType": "aws-ebs-volume",
  "ResourceLocation": "snap-0f4cc9d1d8a094861",
  "ResourceRegion": "eu-central-1",
  "MetaData": {
    "AWSAccountID": "634503960501",
    "SnapshotID": "snap-0f4cc9d1d8a094861",
    "VolumeID": "vol-03b25f8105caf9f00",
    "AttachedInstances": [
      {
        "InstanceID": "i-0076dab31026905f5"
      }
    ]
  }
}
{
    "executionArn": "arn:aws:states:eu-central-1:634503960501:execution:ScannerStateMachine-pueSSKvfdN4K:Manual-EBS-resource-634503960501-635658bd-0deb-42a7-8594-1089d87bfc40",
    "startDate": "2023-03-02T14:36:00.763000+00:00"
}
```

### Script `sentry-trigger-ecr-scan`

The script is region-aware. This means unless you specify it the currently active AWS region from your shell will be used.

Example calls:

```sh
# Help
sentry-trigger-ecr-scan help
```

```sh
Please specify at least the ecr repository to be scanned.

Usage: REPO=<repo-name> [TAG=<image-tag] [REGION=<aws-region>] sentry-trigger-ecr-scan

Example:
  REPO=mawinkler/evil TAG=latest sentry-trigger-ecr-scan
```

```sh
# Trigger scan of ECR repo mawinkler/evil with tag 0.1 existing in the current region
REPO=mawinkler/evil TAG=0.1 sentry-trigger-ecr-scan
```

### Script `sentry-trigger-lambda-scan`

The script is region-aware. This means unless you specify it the currently active AWS region from your shell will be used.

Example calls:

```sh
# Help
sentry-trigger-lambda-scan help
```

```sh
Please specify at least the lambda to be scanned.

Usage: LAMBDA=<lambda-name> [REGION=<aws-region>] sentry-trigger-lambda-scan

Example:
  LAMBDA=cloud-sentry-EbsResourceConsumer sentry-trigger-lambda-scan
```

```sh
# Trigger scan of ECR repo mawinkler/evil with tag 0.1 existing in the current region
LAMBDA=cloud-sentry-EbsResourceConsumer sentry-trigger-lambda-scan
```

### Script `sentry-remove-snapshots`

The script is region-aware. This means unless you specify it the currently active AWS region from your shell will be used.

Example calls:

```sh
# Help
sentry-remove-snapshots help
```

```sh
Usage: [REGION=<aws-region>] [USERNAME=<username-tag>] sentry-remove-snapshots

Example:
  USERNAME=cnctraining sentry-remove-snapshots
```

Example result:

```sh
Using region eu-central-1 for user cnctraining
Snapshot(s) to delete
snap-0f4cc9d1d8a094861
snap-00f0472b795c00644
snap-025d77b5303a37b9d
snap-0b357bbc2fef3edad
snap-07ee34bf66221579d
snap-0b4d1faead597e047
Deleting snapshot snap-0f4cc9d1d8a094861
Deleting snapshot snap-00f0472b795c00644
Deleting snapshot snap-025d77b5303a37b9d
Deleting snapshot snap-0b357bbc2fef3edad
Deleting snapshot snap-07ee34bf66221579d
Deleting snapshot snap-0b4d1faead597e047
```

### Repo C1 Sentry Reports to CloudWatch

Here, I'm describing a simple way to easily get new Sentry reports to CloudWatch using Lambda.

[Repo Link](https://github.com/mawinkler/c1-sentry-reports-to-cloudwatch/blob/main/docs/reports-to-cloudwatch.md)


## Cloud One Container Security

### Scan-Image and Scan-Namespace with Smart Check

The two scripts `scan-image` and `scan-namespace` do what you would expect. Running

```sh
scan-image nginx:latest
```

starts an asynchronous scan of the latest version of nginx. The scan will run on Smart Check, but you are immedeately back in the shell. To access the scan results either use the UI or API of Smart Check.

```json
...
{ critical: 6,
  high: 39,
  medium: 40,
  low: 13,
  negligible: 2,
  unknown: 3 }
```

The script

```sh
scan-namespace.sh
```

scans all used images within the current namespace. Eventually do a `kubectl config set-context --current --namespace <NAMESPACE>` beforehand to select the namespace to be scanned.

### Scan-Image with Artifact Scanning as a Service

The script `scan-assas` do what you would expect, creating a scan request utilizing syft to create an SBOM and upload it to ASaaS for the vulnerability scan. Running

```sh
scan-assas nginx:latest
```

Should do the trick.
