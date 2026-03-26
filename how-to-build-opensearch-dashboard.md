# How to Build OpenSearch Dashboards Docker Image

This document describes the exact process used to build the OpenSearch Dashboards Docker image (version 3.5.0) using the official distribution tarball and the project's build scripts. It covers two base image variants — **Amazon Linux 2023** and **Ubuntu 24.04** — and patching known CVEs in bundled Node.js dependencies.

## Prerequisites

- **Docker:** Installed and running.
- **Curl:** For downloading the distribution artifacts.
- **Bash:** For executing the build scripts.

## Step 1: Download the OpenSearch Dashboards Tarball

Instead of building from source (which is resource-intensive), we use the official pre-built Linux x64 distribution.

```bash
# Create a distribution directory
mkdir -p dist

# Download OpenSearch Dashboards 3.5.0 tarball
curl -L https://artifacts.opensearch.org/releases/bundle/opensearch-dashboards/3.5.0/opensearch-dashboards-3.5.0-linux-x64.tar.gz -o dist/opensearch-dashboards-3.5.0-linux-x64.tar.gz
```

## Step 2: Build the Docker Image

We use the `build-image-single-arch.sh` script located in the `docker/release` directory. This script automates the process of preparing the Docker context (copying configs, entrypoints, etc.) and executing `docker build`.

### Option A: Amazon Linux 2023 (default)

```bash
# Navigate to the release directory
cd docker/release

# Execute the build script
./build-image-single-arch.sh \
  -v 3.5.0 \
  -f ./dockerfiles/opensearch-dashboards.al2023.dockerfile \
  -p opensearch-dashboards \
  -a x64 \
  -t ../../dist/opensearch-dashboards-3.5.0-linux-x64.tar.gz
```

### Option B: Ubuntu 24.04

```bash
# Navigate to the release directory
cd docker/release

# Execute the build script
./build-image-single-arch.sh \
  -v 3.5.0 \
  -f ./dockerfiles/opensearch-dashboards.ubuntu2404.dockerfile \
  -p opensearch-dashboards \
  -a x64 \
  -t ../../dist/opensearch-dashboards-3.5.0-linux-x64.tar.gz
```

### Script Arguments Explained:
- `-v 3.5.0`: The version of OpenSearch Dashboards. This is used for image tagging and labeling.
- `-f ./dockerfiles/<dockerfile>`: The Dockerfile to use. Available options:
  - `opensearch-dashboards.al2023.dockerfile` — Amazon Linux 2023
  - `opensearch-dashboards.ubuntu2404.dockerfile` — Ubuntu 24.04
- `-p opensearch-dashboards`: The product name. This tells the script which configuration files to pull from `docker/release/config/opensearch-dashboards`.
- `-a x64`: The target architecture.
- `-t ../../dist/opensearch-dashboards-3.5.0-linux-x64.tar.gz`: The path to the local tarball we downloaded in Step 1.

### Base Image Comparison

| | Amazon Linux 2023 | Ubuntu 24.04 |
|---|---|---|
| **Base image** | `public.ecr.aws/amazonlinux/amazonlinux:2023` | `ubuntu:24.04` |
| **Package manager** | `dnf` | `apt-get` |
| **User creation** | `adduser` (creates home dir automatically) | `useradd -m` (requires `-m` flag) |
| **UID/GID 1000** | Available by default | Requires removing default `ubuntu` user first |
| **Reporting deps** | `nss`, `xorg-x11-fonts-*`, `freetype` | `libnss3`, `xfonts-*`, `libfreetype6` |

## Step 3: Verify the Image

After the build completes, verify that the image exists in your local Docker registry.

```bash
docker images | grep opensearch-dashboards
```

Expected output:
```text
opensearchproject/opensearch-dashboards    3.5.0    <IMAGE_ID>    ...
```

## Step 4: List Bundled Plugins

The official tarball ships with the following 16 plugins pre-installed:

```bash
docker run --rm opensearchproject/opensearch-dashboards:3.5.0 ls -1 /usr/share/opensearch-dashboards/plugins/
```

| Plugin | Description |
|--------|-------------|
| alertingDashboards | Create and manage alerts and triggers |
| anomalyDetectionDashboards | Detect anomalies in your data using ML |
| assistantDashboards | AI assistant integration |
| customImportMapDashboards | Custom import map support |
| flowFrameworkDashboards | Workflow and automation framework |
| indexManagementDashboards | Manage index policies and rollups |
| investigationDashboards | Security investigation tools |
| mlCommonsDashboards | Machine learning commons interface |
| notificationsDashboards | Notification channels and destinations |
| observabilityDashboards | Traces, metrics, and log analytics |
| queryInsightsDashboards | Query performance insights |
| queryWorkbenchDashboards | SQL and PPL query workbench |
| reportsDashboards | Generate and schedule reports |
| searchRelevanceDashboards | Compare and tune search relevance |
| securityAnalyticsDashboards | Security event analytics and correlation |
| securityDashboards | Role-based access control and authentication |

## Step 5: CVE Patching

Both Dockerfiles (`opensearch-dashboards.al2023.dockerfile` and `opensearch-dashboards.ubuntu2404.dockerfile`) include an identical automated CVE patching step that runs during image build. It installs `npm` temporarily, downloads fixed package versions to a staging area, replaces all vulnerable copies in-place, and then removes `npm` to keep the final image clean.

The following CVEs across 13 packages are patched (HIGH and CRITICAL are prioritized):

| Package | Vulnerable | Fixed | CVEs | Severity |
|---------|-----------|-------|------|----------|
| basic-ftp | 5.0.5 | 5.2.0 | CVE-2026-27699 | CRITICAL |
| fast-xml-parser | 4.4.1 / 5.2.5 | 5.5.6 | CVE-2026-25896, CVE-2026-25128, CVE-2026-26278, CVE-2026-27942, CVE-2026-33036 | CRITICAL/HIGH |
| jspdf | 4.1.0 | 4.2.1 | CVE-2026-31938, CVE-2026-25535, CVE-2026-25755, CVE-2026-25940, CVE-2026-31898 | CRITICAL/HIGH |
| serialize-javascript | 6.0.2 | 7.0.3 | GHSA-5c6j-r48x-rmvq | HIGH |
| axios | 1.13.3 | 1.13.5 | CVE-2026-25639 | HIGH |
| ajv | 8.12.0 | 8.18.0 | CVE-2025-69873 | MEDIUM |
| bn.js | 4.12.0 | 4.12.3 | CVE-2026-2739 | MEDIUM |
| dompurify | 3.2.4 | 3.3.2 | CVE-2025-15599, CVE-2026-0540 | MEDIUM |
| @smithy/config-resolver | 4.1.0 / 4.3.0 | 4.4.0 | GHSA-6475-r3vj-m8vf | LOW |
| @tootallnate/once | 2.0.0 | 3.0.1 | CVE-2026-3449 | LOW |
| minimatch | 3.1.2 | 3.1.4 | CVE-2026-26996, CVE-2026-27903, CVE-2026-27904 | LOW |
| tar | 7.5.7 | 7.5.11 | CVE-2026-26960, CVE-2026-29786, CVE-2026-31802 | LOW |

### Patched Locations

The patching process uses a surgical replacement strategy. Instead of a broad search, it targets the exact folders reported in the vulnerability scan (e.g., `trivy-detech-cves.log`). This ensures that only the affected instances of a package are modified, maintaining the integrity of the rest of the installation.

Key target areas include:
- **Top-level dependencies** in `node_modules/`
- **Deeply nested dependencies** within specific libraries (e.g., `@aws-sdk/xml-builder`, `asn1.js`)
- **Plugin-specific dependencies** (e.g., `assistantDashboards`, `reportsDashboards`, `securityDashboards`, etc.)

This approach provides a deterministic and verifiable way to remediate CVEs while minimizing changes to the original distribution.

## Step 6: Run the Image

You can run the newly built (and CVE-patched) image using the following command. Note that OpenSearch Dashboards requires a running OpenSearch backend to connect to.

```bash
# First, start an OpenSearch node
docker run -d --name opensearch-node \
  -p 9200:9200 \
  -e "discovery.type=single-node" \
  -e "OPENSEARCH_INITIAL_ADMIN_PASSWORD=MyStr0ngP@ssw0rd!" \
  opensearchproject/opensearch:3.5.0

# Then, start OpenSearch Dashboards and link it to the OpenSearch node
docker run -it \
  -p 5601:5601 \
  --link opensearch-node:opensearch-node \
  -e "OPENSEARCH_HOSTS=https://opensearch-node:9200" \
  opensearchproject/opensearch-dashboards:3.5.0
```

Once running, access OpenSearch Dashboards at [http://localhost:5601](http://localhost:5601).

## Step 7: Run with Docker Compose

For a more robust setup involving both OpenSearch and OpenSearch Dashboards, use Docker Compose.

### Create `docker-compose.yml`

Create a file named `docker-compose.yml` with the following content:

```yaml
services:
  opensearch-node:
    image: opensearchproject/opensearch:3.5.0
    container_name: opensearch-node
    environment:
      - cluster.name=opensearch-cluster
      - node.name=opensearch-node
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=MyStr0ngP@ssw0rd!
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    ports:
      - 9200:9200
    networks:
      - opensearch-net

  opensearch-dashboards:
    image: opensearchproject/opensearch-dashboards:3.5.0
    container_name: opensearch-dashboards
    ports:
      - 5601:5601
    environment:
      OPENSEARCH_HOSTS: '["https://opensearch-node:9200"]'
    networks:
      - opensearch-net
    depends_on:
      - opensearch-node

networks:
  opensearch-net:
```

### Start the Services

```bash
docker compose up -d
```

### Verify Plugins

Once the container is running, you can list the installed plugins:

```bash
docker exec opensearch-dashboards ls -1 /usr/share/opensearch-dashboards/plugins/
```

