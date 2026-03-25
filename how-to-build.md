# Building OpenSearch and OpenSearch Dashboards

This guide provides step-by-step instructions for building OpenSearch and OpenSearch Dashboards distributions (with all plugins) and their corresponding Docker images.

## Prerequisites

- **Java:** OpenSearch 2.x and later require Java 11 or higher (OpenJDK 17/21 is recommended).
- **Python:** Python 3.8 or higher with `pipenv` or `pip`.
- **Docker:** Installed and running (required for building Docker images).
- **Gradle:** Required for OpenSearch builds.
- **Node.js:** Required for OpenSearch Dashboards builds (version specified in `.nvmrc`).
- **Yarn:** Required for OpenSearch Dashboards and plugin builds.

## 1. Build from Source

The build process uses **manifests** as the source of truth. Each manifest declares the core component and all plugins to be built, along with their git repositories and refs.

### Build OpenSearch
```bash
./build.sh manifests/3.6.0/opensearch-3.6.0.yml
```

### Build OpenSearch Dashboards (with all plugins)

```bash
./build.sh manifests/3.6.0/opensearch-dashboards-3.6.0.yml
```

This single command builds **OpenSearch Dashboards core** first, then builds **all plugins** declared in the manifest. The core must be built first because plugins depend on it for bootstrapping.

**Plugins included in 3.6.0 manifest:**

| Plugin Name | Repository | Description |
|---|---|---|
| observabilityDashboards | dashboards-observability | Observability (logs, traces, metrics) |
| reportsDashboards | dashboards-reporting | Report generation and scheduling |
| queryWorkbenchDashboards | dashboards-query-workbench | SQL/PPL query workbench |
| customImportMapDashboards | dashboards-maps | Custom map visualizations |
| anomalyDetectionDashboards | anomaly-detection-dashboards-plugin | Anomaly detection UI |
| mlCommonsDashboards | ml-commons-dashboards | ML Commons UI |
| indexManagementDashboards | index-management-dashboards-plugin | Index State Management UI |
| notificationsDashboards | dashboards-notifications | Notification channels and configs |
| alertingDashboards | alerting-dashboards-plugin | Alerting monitors and destinations |
| securityAnalyticsDashboards | security-analytics-dashboards-plugin | Security analytics (threat detection) |
| securityDashboards | security-dashboards-plugin | Authentication and access control UI |
| searchRelevanceDashboards | dashboards-search-relevance | Search relevance comparison tool |
| assistantDashboards | dashboards-assistant | AI assistant integration |
| flowFrameworkDashboards | dashboards-flow-framework | Flow framework (workflow builder) |
| queryInsightsDashboards | query-insights-dashboards | Query insights and top N queries |
| investigationDashboards | dashboards-investigation | Investigation workspace |

**Build output** is placed into `builds/opensearch-dashboards/`:
```
builds/opensearch-dashboards/
├── dist/
│   └── opensearch-dashboards-min-3.6.0-linux-x64.tar.gz   # Core min tarball
├── plugins/
│   ├── observabilityDashboards/
│   │   └── dashboards-observability-3.6.0.0.zip
│   ├── securityDashboards/
│   │   └── opensearch-security-dashboards-3.6.0.0.zip
│   └── ... (one folder per plugin)
└── manifest.yml   # Build manifest with all component details
```

### build.sh Options

| Option | Description |
|---|---|
| `-s, --snapshot` | Build a snapshot version (default: false) |
| `-p, --platform` | Target platform: `linux`, `darwin`, `windows` (default: current system) |
| `-a, --architecture` | Target architecture: `x64`, `arm64` (default: current system) |
| `-d, --distribution` | Distribution type: `tar`, `zip`, `rpm`, `deb` (default: tar) |
| `-c, --component [names]` | Build only specific components, e.g. `--component securityDashboards alertingDashboards` |
| `-i, --incremental` | Rebuild only changed components (compares against previous build manifest) |
| `--continue-on-error` | Continue building other plugins if one fails |
| `-l, --lock` | Generate a stable reference manifest with pinned commit SHAs |
| `--keep` | Keep the temporary working directory after build |
| `-v, --verbose` | Show verbose output |

**Examples:**

```bash
# Build snapshot with all plugins
./build.sh manifests/3.6.0/opensearch-dashboards-3.6.0.yml --snapshot

# Build only specific plugins (core must already be built)
./build.sh manifests/3.6.0/opensearch-dashboards-3.6.0.yml --component securityDashboards alertingDashboards

# Build for a specific platform and architecture
./build.sh manifests/3.6.0/opensearch-dashboards-3.6.0.yml --platform linux --architecture arm64

# Incremental build (only changed components)
./build.sh manifests/3.6.0/opensearch-dashboards-3.6.0.yml --incremental
```

## 2. Assemble Distribution

After the build step, **assemble** installs all built plugins into the core Dashboards distribution to produce the final artifact.

### Assemble OpenSearch
```bash
./assemble.sh builds/opensearch/manifest.yml
```

### Assemble OpenSearch Dashboards (with all plugins)
```bash
./assemble.sh builds/opensearch-dashboards/manifest.yml
```

The assembly process:
1. Extracts the core Dashboards min tarball from `builds/opensearch-dashboards/dist/`
2. Installs each plugin zip using `opensearch-dashboards-plugin install file:<path>`
3. Runs any component-specific install scripts (from `scripts/components/<name>/install.sh`)
4. Packages the final distribution

**Assembled output** in `dist/`:
```
dist/
├── opensearch-dashboards-3.6.0-linux-x64.tar.gz          # Final distribution with all plugins
├── opensearch-dashboards-3.6.0-linux-x64.tar.gz.sha512   # Checksum
└── manifest.yml                                           # Bundle manifest
```

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
