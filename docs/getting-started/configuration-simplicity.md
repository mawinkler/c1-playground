# Getting Started Configuration

From within the main menu choose `Edit Configuration`

Typically you don't need to change anything here besides setting your api-key and region for Cloud One. If you intent to run multiple clusters (e.g. a local and a GKE), adapt the `cluster_name` and the `policy_name`.

```yaml
## Kubernetes cluster name
##
## Default value: playground
cluster_name: playground

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
```
