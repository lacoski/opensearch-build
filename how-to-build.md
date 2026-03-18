# Building OpenSearch and OpenSearch Dashboards

This guide provides step-by-step instructions for building OpenSearch and OpenSearch Dashboards distributions and their corresponding Docker images.

## Prerequisites

- **Java:** OpenSearch 2.x and later require Java 11 or higher (OpenJDK 17/21 is recommended).
- **Python:** Python 3.8 or higher with `pipenv` or `pip`.
- **Docker:** Installed and running (required for building Docker images).
- **Gradle:** Required for OpenSearch builds.
- **Node.js:** Required for OpenSearch Dashboards builds.

## 1. Build from Source

The build process uses manifests as the source of truth.

### Build OpenSearch
```bash
./build.sh manifests/3.6.0/opensearch-3.6.0.yml
```

### Build OpenSearch Dashboards
```bash
./build.sh manifests/3.6.0/opensearch-dashboards-3.6.0.yml
```

This will create a build manifest in the `builds/` directory.

## 2. Assemble Distribution

After the build is complete, you need to assemble the distribution.

### Assemble OpenSearch
```bash
./assemble.sh builds/opensearch/manifest.yml
```

### Assemble OpenSearch Dashboards
```bash
./assemble.sh builds/opensearch-dashboards/manifest.yml
```

The assembled distribution (tarball) will be available in the `dist/` directory.

## 3. Build Docker Images

Docker images are built using scripts in the `docker/release/` folder.

### Step 1: Navigate to the Docker Release directory
```bash
cd docker/release
```

### Step 2: Build the Image
You can build a single-architecture image using the following command. You will need the assembled tarball from the previous step.

**Required Files for Docker Build:**
The Docker build script expects certain configuration files to be present in the build context. These are typically handled by the `build-image-single-arch.sh` script, but you should ensure the following are available (often sourced from the `docker/release/config` directory):
- `opensearch.yml` or `opensearch_dashboards.yml`
- `log4j2.properties`
- `opensearch-docker-entrypoint.sh`

**For OpenSearch:**
```bash
./build-image-single-arch.sh \
  -v 3.6.0 \
  -f ./dockerfiles/opensearch.al2.dockerfile \
  -p opensearch \
  -a x64 \
  -t ../../dist/opensearch-3.6.0-linux-x64.tar.gz
```

**For OpenSearch Dashboards:**
```bash
./build-image-single-arch.sh \
  -v 3.6.0 \
  -f ./dockerfiles/opensearch-dashboards.al2.dockerfile \
  -p opensearch-dashboards \
  -a x64 \
  -t ../../dist/opensearch-dashboards-3.6.0-linux-x64.tar.gz
```

### Command Options:
- `-v`: Version (e.g., 3.6.0)
- `-f`: Dockerfile path
- `-p`: Product name (opensearch or opensearch-dashboards)
- `-a`: Architecture (x64 or arm64)
- `-t`: Path to the local distribution tarball
