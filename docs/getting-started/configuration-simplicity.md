# Getting Started Configuration

From within the main menu choose `Edit Configuration`

Typically you don't need to change much here besides setting your api-key and region for Cloud One.

If you intent to use Artifact Scanning as a Service create a scanner api-key in Cloud One and set it as `scanner_api_key`.

When willing to play with the built-in AWSONE environment (`terraform-awsone`) you need to set the relevant values for Workload Security and Vision One, of course.

```yaml
## Kubernetes cluster name
##
## Default value: playground
cluster_name: playground

## Kubernetes cluster node instance type (AWS)
##
## Default value: playground
cluster_instance_type: t3.medium

## Editor for Playground. Defaults to autodetection of nano over vim and vi
##
## Default value: ''
editor: vim

services:
  - name: cloudone
    ## Cloud One region to work with
    ## 
    ## Default value: trend-us-1
    region: us-1

    ## Cloud One instance to use
    ##
    ## Allowed values: cloudone, staging-cloudone, dev-cloudone
    ## 
    ## Default value: cloudone
    instance: cloudone

    ## Cloud One API Key with Full Access
    ## 
    ## REQUIRED if you want to play with Cloud One
    ##
    ## Default value: ''
    api_key: YOUR CLOUD ONE API KEY HERE

    ## Cloud One Scanner API Key
    ## 
    ## REQUIRED if you want to play with Artifac Scanning as a Service
    ##
    ## Default value: ''
    scanner_api_key: ''

    ## Cloud One Workload Security Tenant ID
    ## 
    ## REQUIRED if you want to play with Cloud One Workload Security
    ##
    ## Default value: ''
    ws_tenant_id: ''

    ## Cloud One Workload Security Token
    ## 
    ## REQUIRED if you want to play with Cloud One Workload Security
    ##
    ## Default value: ''
    ws_token: ''

    ## Cloud One Workload Security Linux Policy ID
    ## 
    ## REQUIRED if you want to play with Cloud One Workload Security
    ##
    ## Default value: ''
    ws_policy_id: ''

  - name: visionone

    ## Vision One Basecamp agent download url
    ##
    ## REQUIRED if you want to play with Vision One
    ##
    ## Default value: ''
    xbc_agent_url: ''

  - name: container_security
    ## The name of the created or reused policy
    ## 
    ## Default value: relaxed_playground
    policy_name: relaxed_playground

    ## Target namespace for Smart Check
    ## 
    ## Default value: trendmicro-system
    namespace: trendmicro-system

  # ================ DO NOT CHANGE ANYTHING BELOW THIS LINE ===============
  # ================== UNLESS YOU KNOW WHAT YOU'RE DOING ==================
...
```
