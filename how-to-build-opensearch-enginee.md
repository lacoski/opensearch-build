# How to Build OpenSearch Engine Docker Image

This document describes the exact process used to build the OpenSearch Engine Docker image (version 3.5.0) using the official distribution tarball and the project's build scripts.

## Prerequisites

- **Docker:** Installed and running.
- **Curl:** For downloading the distribution artifacts.
- **Bash:** For executing the build scripts.

## Step 1: Download the OpenSearch Tarball

Instead of building from source (which is resource-intensive), we use the official pre-built Linux x64 distribution.

```bash
# Create a distribution directory
mkdir -p dist

# Download OpenSearch 3.5.0 tarball
curl -L https://artifacts.opensearch.org/releases/bundle/opensearch/3.5.0/opensearch-3.5.0-linux-x64.tar.gz -o dist/opensearch-3.5.0-linux-x64.tar.gz
```

## Step 2: Build the Docker Image

We use the `build-image-single-arch.sh` script located in the `docker/release` directory. This script automates the process of preparing the Docker context (copying configs, entrypoints, etc.) and executing `docker build`.

```bash
# Navigate to the release directory
cd docker/release

# Execute the build script
./build-image-single-arch.sh \
  -v 3.5.0 \
  -f ./dockerfiles/opensearch.al2023.dockerfile \
  -p opensearch \
  -a x64 \
  -t ../../dist/opensearch-3.5.0-linux-x64.tar.gz
```

### Script Arguments Explained:
- `-v 3.5.0`: The version of OpenSearch. This is used for image tagging and labeling.
- `-f ./dockerfiles/opensearch.al2023.dockerfile`: The Dockerfile to use. We chose the Amazon Linux 2023 version.
- `-p opensearch`: The product name. This tells the script which configuration files to pull from `docker/release/config/opensearch`.
- `-a x64`: The target architecture.
- `-t ../../dist/opensearch-3.5.0-linux-x64.tar.gz`: The path to the local tarball we downloaded in Step 1.

## Step 3: Verify the Image

After the build completes, verify that the image exists in your local Docker registry.

```bash
docker images | grep opensearch
```

Expected output:
```text
opensearchproject/opensearch    3.5.0    <IMAGE_ID>    ...
```

## Step 4: Run the Image

You can now run the newly built image using the following command:

```bash
docker run -it \
  -p 9200:9200 \
  -p 9600:9600 \
  -e "discovery.type=single-node" \
  -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=<your-strong-password>" \
  opensearchproject/opensearch:3.5.0
```
