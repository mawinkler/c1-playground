# Add-On: GitLab

## Deploy

> ***Note:*** The script `deploy-gitlab.sh` deploys a GitLab with Docker Pipeline Support directly on the Docker engine. In other words, GitLab does *NOT* run on Kubernetes but locally on your machine. This is because GitLab needs to have access to the Docker Socket which is typically not available anymore on managed clusters nor easily within Kind.

To deploy GitLab run:

```sh
deploy-gitlab.sh
```

GitLabs configuration is stored on the host within the directories `/srv/gitlab` and `/srv/gitlab-runner`. The configuration survives restart and a full delete-deploy operation. If you need to restart from scratch delete the two directories.

## Access GitLab

By default GitLab listens on Port 80. The login credentials for the initial login are reported in the `Services` item of the Playground Menu.

<http://localhost>

***Cloud9***

If working on a Cloud9 environment you need to adapt the security group of the corresponding EC2 instance to enable access from your browser. To share GitLab over the internet, follow the steps below.

1. Query the public IP of your Cloud9 instance with

   ```sh
   curl http://169.254.169.254/latest/meta-data/public-ipv4
   ```

2. In the IDE for the environment, on the menu bar, choose your user icon, and then choose Manage EC2 Instance
3. Select the security group associated to the instance and select Edit inbound rules.
4. Add an inbound rule for the GitLab port (`80`) configured in you config.yaml and choose Source Anywhere (or your personal IP address of course)
5. Depending on the currently configured Network ACL you might need to add a rule to allow ingoing traffic on the same port. To do this go to the VPC within the Cloud9 instance is running and proceed to the associated Main network ACL.
6. Ensure that an inbound rule is set which allows traffic on the port from above. If not, click on `Edit inbound rules` and add a rule with a low Rule number, Custom TCP, Port range 80 (or your configured port), Source 0.0.0.0/0 (or your IP address) and Allow.

You should now be able to connect to GitLab on the public ip of your Cloud9 with your configured port.

## Configure GitLab

Depending on what you're going to do with GitLab some little configuration steps are typically required.

Environment Variables

- CI_COMMIT_BRANCH: main
- CI_DEFAULT_BRANCH: main
- CI_REGISTRY_IMAGE: mawinkler/helloworld
- CI_REGISTRY_PASSWORD: DOCKER_PASSWORD
- CI_REGISTRY_USER: mawinkler

Pipeline:

```yaml
# Build a Docker image with CI/CD and push to the GitLab registry.
# Docker-in-Docker documentation: https://docs.gitlab.com/ee/ci/docker/using_docker_build.html
#
# This template uses one generic job with conditional builds
# for the default branch and all other (MR) branches.

docker-build:
  # Use the official docker image.
  image: docker:latest
  stage: build
  services:
    - docker:dind
  before_script:
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD"
    #$CI_REGISTRY
  # Default branch leaves tag empty (= latest tag)
  # All other branches are tagged with the escaped branch name (commit ref slug)
  script:
    - |
      if [[ "$CI_COMMIT_BRANCH" == "$CI_DEFAULT_BRANCH" ]]; then
        tag=""
        echo "Running on default branch '$CI_DEFAULT_BRANCH': tag = 'latest'"
      else
        tag=":$CI_COMMIT_REF_SLUG"
        echo "Running on branch '$CI_COMMIT_BRANCH': tag = $tag"
      fi
    - docker build --pull -t "$CI_REGISTRY_IMAGE${tag}" .
    - docker push "$CI_REGISTRY_IMAGE${tag}"
  # Run this job in a branch where a Dockerfile exists
  rules:
    - if: $CI_COMMIT_BRANCH
      exists:
        - Dockerfile
  tags:
    - docker
```

Dockerfile:

```Dockerfile
FROM ubuntu

COPY helloworld.sh /
RUN chmod 700 /helloworld.sh

ENTRYPOINT /helloworld.sh
```

Script:

```sh
#!/bin/bash
echo HelloWorld script within Docker image
exit 0
```
