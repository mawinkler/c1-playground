# Add-On: KUBEClarity

KubeClarity is a tool for detection and management of Software Bill Of Materials (SBOM) and vulnerabilities of container images and filesystems. It scans both runtime K8s clusters and CI/CD pipelines for enhanced software supply chain security.

Source Repo: [here](https://github.com/openclarity/kubeclarity)
## Deploy KUBEClarity

The deployment of KUBEClarity runtime security is very straigt forward with the playground. Simply execute the script `deploy-kubeclarity.sh`, everything else is prepared.

```sh
deploy-kubeclarity.sh
```

## Access

Follow the steps for your platform below. A file called `services` is either created or updated with the link and the credentials to connect to KUBEClarity.

## CLI

KubeClarity includes a CLI that can be run locally and especially useful for CI/CD pipelines.
It allows to analyze images and directories to generate SBOM, and scan it for vulnerabilities.
The results can be exported to KubeClarity backend.

### Installation

Download the release distribution for your OS from the
[releases page](https://github.com/openclarity/kubeclarity/releases)

Unpack the `kubeclarity-cli` binary, add it to your PATH, and you are good to go!

Alternatively, simply run the command below:

```sh
curl -sL https://github.com/openclarity/kubeclarity/releases/download/v2.14.0/kubeclarity-cli-2.14.0-linux-amd64.tar.gz \
  -o /tmp/kubeclarity-cli.tar.gz && \
  tar xfvz /tmp/kubeclarity-cli.tar.gz kubeclarity-cli && \
  mv kubeclarity-cli ${PGPATH}/bin && \
  rm /tmp/kubeclarity-cli.tar.gz
```

### SBOM Generation

Usage:
```
kubeclarity-cli analyze <image/directory name> --input-type <dir|file|image(default)> -o <output file or stdout>
```

Example:
```
kubeclarity-cli analyze --input-type image nginx:latest -o nginx.sbom
```

Optionally a list of the content analyzers to use can be configured using the `ANALYZER_LIST` env
variable seperated by a space (e.g `ANALYZER_LIST="<analyzer 1 name> <analyzer 2 name>"`)

Example:
```
ANALYZER_LIST="syft gomod" kubeclarity-cli analyze --input-type image nginx:latest -o nginx.sbom
```

### Vulnerability Scanning

Usage:
```
kubeclarity-cli scan <image/sbom/directoty/file name> --input-type <sbom|dir|file|image(default)> -f <output file>
```

Example:
```
kubeclarity-cli scan nginx.sbom --input-type sbom
```

Optionally a list of the vulnerability scanners to use can be configured using the `SCANNERS_LIST` env
variable seperated by a space (e.g `SCANNERS_LIST="<Scanner1 name> <Scanner2 name>"`)

Example:
```
SCANNERS_LIST="grype trivy" kubeclarity-cli scan nginx.sbom --input-type sbom
```

### Exporting Results to KubeClarity Backend

To export CLI results to the KubeClarity backend, need to use an application ID as defined by the KubeClarity backend.
The application ID can be found in the Applications screen in the UI or using the KubeClarity API.