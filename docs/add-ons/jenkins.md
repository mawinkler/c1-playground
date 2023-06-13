# Add-On: Jenkins

> ***TODO:*** Remove Smart Check from sample pipeline

## Deploy

> ***Note:*** The script `deploy-jenkins.sh` deploys a Jenkins with Docker Pipeline Support and BlueOcean directly on the Docker engine. In other words, Jenkins does *NOT* run on Kubernetes but locally on your machine. This is because Jenkins needs to have access to the Docker Socket which is typically not available anymore on managed clusters nor easily within Kind.

To deploy Jenkins run:

```sh
deploy-jenkins.sh
```

## Access Jenkins

By default Jenkins listens on Port 8080. The login credentials for the initial login are reported in the `Services` item of the Playground Menu. The password is for one time use only. After logging in to

<http://localhost:8080>

You will be prompted for it. In the following you need to create the initial admin user. There are no password policies set, so an `admin / trendmicro` will work :-).

Next, deploy the recommended plug-ins and head over to the Jenkins console.

***Cloud9***

If working on a Cloud9 environment you need to adapt the security group of the corresponding EC2 instance to enable access from your browser. To share Jenkins over the internet, follow the steps below.

1. Query the public IP of your Cloud9 instance with

   ```sh
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

2. In the IDE for the environment, on the menu bar, choose your user icon, and then choose Manage EC2 Instance
3. Select the security group associated to the instance and select Edit inbound rules.
4. Add an inbound rule for the Jenkins port (`8080`) configured in you config.yaml and choose Source Anywhere (or your personal IP address of course)
5. Depending on the currently configured Network ACL you might need to add a rule to allow ingoing traffic on the same port. To do this go to the VPC within the Cloud9 instance is running and proceed to the associated Main network ACL.
6. Ensure that an inbound rule is set which allows traffic on the port from above. If not, click on `Edit inbound rules` and add a rule with a low Rule number, Custom TCP, Port range 8080 (or your configured port), Source 0.0.0.0/0 (or your IP address) and Allow.

You should now be able to connect to Jenkins on the public ip of your Cloud9 with your configured port.

## Configure Jenkins

Depending on what you're going to do with Jenkins some little configuration steps are typically required.

I believe the required steps are best demonstrated by an example.

Let's assume we want to scan an image from ACR with Smart Check and want to get a pdf report created if the scan reports vulnerability findings. The report is then filed as an artifact within the pipeline run.

The pipeline will require two credentials:

1. Azure Container Registry
2. Smart Check

To create them in Jenkins head over to `Manage Jenkins --> Manage Credentials`.

Create two crendentials in the global domain as `Username with password`. Name the one for ACR as `acr-auth` and the smart check one as `smartcheck-auth`.

Additionally, we need to tell Jenkins where to find Smart Check. For this we do create an environment variable. So head over to `Manage Jenkins --> Configure System`. Scroll down to the `Global Properties`, check `Environment variables` and `[Add]`. Name the variable as `DSSC_SERVICE` with the IP:Port of your Smart Check instance (e.g. `<ip of your server>:8443` which is the address of the nginx proxy deployed by the Smart Check deployment script forwarding to your Smart Check running on a kind Kubernetes cluster).

Hit `[Save]`.

Then, back on the main dashboard of Jenkins hit `+ New Item`, enter an item name (e.g. `ACR Scan`) and click on `Pipeline` followed by `[OK]`.

For our simple example you can leave all the options unchecked. Into the `Pipeline`-section paste the following groovy code:

```groovy
pipeline {
  agent any
 
  stages {
    stage('Test') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'smartcheck-auth',
            usernameVariable: 'SMARTCHECK_AUTH_CREDS_USR',
            passwordVariable: 'SMARTCHECK_AUTH_CREDS_PSW'
          ),
          usernamePassword(
            credentialsId: 'acr-auth',
            usernameVariable: 'ACR_AUTH_CREDS_USR',
            passwordVariable: 'ACR_AUTH_CREDS_PSW'
          )
        ]) { 
          script {
            try {
              sh """
              docker run deepsecurity/smartcheck-scan-action \
                --image-name astrolive.azurecr.io/astrolive:latest \
                --smartcheck-host=$DSSC_SERVICE \
                --smartcheck-user=$SMARTCHECK_AUTH_CREDS_USR \
                --smartcheck-password=$SMARTCHECK_AUTH_CREDS_PSW \
                --insecure-skip-tls-verify=true \
                --image-pull-auth=\'{"username": "$ACR_AUTH_CREDS_USR", "password": "$ACR_AUTH_CREDS_PSW"}\'
              """
            } catch(e) {
              script {
                docker.image('mawinkler/scan-report').pull()
                docker.image('mawinkler/scan-report').inside("--entrypoint=''") {
                  sh """
                    python /usr/src/app/scan-report.py \
                      --config_path "/usr/src/app" \
                      --name "astrolive" \
                      --image_tag "latest" \
                      --out_path "${WORKSPACE}" \
                      --service "${DSSC_SERVICE}" \
                      --username "${SMARTCHECK_AUTH_CREDS_USR}" \
                      --password "${SMARTCHECK_AUTH_CREDS_PSW}"
                  """
                  archiveArtifacts artifacts: 'report_*.pdf'
                }
                error('Issues in image found')
              }
            }
          }
        }
      }
    }
  }
}
```

Hit `[Save]` and start the build with `Build Now`. If you want see the build progress click on the currently running build in the lower left area of your Jenkins. Within the `Console Output` you should see the output generated by your first Jenkins pipeline :-).
