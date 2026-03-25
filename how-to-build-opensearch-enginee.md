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

# Execute the build script (Ubuntu 24.04 example)
./build-image-single-arch.sh \
  -v 3.5.0 \
  -f ./dockerfiles/opensearch.ubuntu2404.dockerfile \
  -p opensearch \
  -a x64 \
  -t ../../dist/opensearch-3.5.0-linux-x64.tar.gz
```

### Script Arguments Explained:
- `-v 3.5.0`: The version of OpenSearch. This is used for image tagging and labeling.
- `-f ./dockerfiles/opensearch.ubuntu2404.dockerfile`: The Dockerfile to use.
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

## Troubleshooting & Common Issues

During the build and startup of OpenSearch 3.5.0, several critical issues were identified and resolved in the Dockerfile.

### 1. Jar Hell Conflict & Shaded Vulnerabilities
**Symptom:** The container fails to start with `java.lang.IllegalStateException: failed to load plugin opensearch-security due to jar hell` OR Trivy reports HIGH CVEs in `opensaml-3.5.0.0-all.jar`.
**Cause:** `opensaml` shades an old version of Jackson. Adding new Jackson JARs to the plugin directory causes duplication (jar hell).
**Fix:** Removed the redundant Jackson classes from `opensaml-3.5.0.0-all.jar` using `zip -d`. This allows `opensaml` to use the fixed standalone Jackson JARs without conflict.

### 2. Jackson Compatibility Errors (NoSuchFieldError / ClassNotFoundException)
**Symptom:** The container starts but crashes with:
- `java.lang.NoSuchFieldError: CLEAR_CURRENT_TOKEN_ON_CLOSE`
- `java.lang.ClassNotFoundException: com.fasterxml.jackson.annotation.JsonSerializeAs`
**Cause:** Inconsistent Jackson versions. Some features (like `JsonSerializeAs`) are only available in specific `jackson-annotations` versions (e.g., 2.21).
**Fix:** Use consistent, latest fixed versions across all Jackson components:
- **Jackson Core:** 2.21.1
- **Jackson Databind:** 2.21.1
- **Jackson Annotations:** 2.21 (Required for `JsonSerializeAs`)

### Helpful Debugging Commands

If the container fails to start, check the logs immediately:
```bash
docker logs <container_id_or_name>
```

To inspect the versions of JAR files bundled in the distribution:
```bash
tar -tf dist/opensearch-3.5.0-linux-x64.tar.gz | grep jackson
```

To verify if a specific class/method exists in a JAR file:
```bash
# Using a temporary JDK container
docker run --rm -v $(pwd):/tmp eclipse-temurin:21 javap -cp /tmp/path/to/jar com.package.ClassName
```
