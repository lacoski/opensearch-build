# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0


# This dockerfile generates an Ubuntu 24.04-based image containing an OpenSearch-Dashboards installation.
# It assumes that the working directory contains four files: an OpenSearch-Dashboards tarball (opensearch-dashboards.tgz), opensearch_dashboards.yml, opensearch-dashboards-docker-entrypoint.sh, and example certs.
# Build arguments:
#   VERSION: Required. Used to label the image.
#   BUILD_DATE: Required. Used to label the image. Should be in the form 'yyyy-mm-ddThh:mm:ssZ', i.e. a date-time from https://tools.ietf.org/html/rfc3339. The timestamp must be in UTC.
#   UID: Optional. Specify the opensearch-dashboards userid. Defaults to 1000.
#   GID: Optional. Specify the opensearch-dashboards groupid. Defaults to 1000.
#   OPENSEARCH_DASHBOARDS_HOME: Optional. Specify the opensearch-dashboards root directory. Defaults to /usr/share/opensearch-dashboards.

########################### Stage 0 ########################
FROM ubuntu:24.04 AS linux_stage_0

ARG UID=1000
ARG GID=1000
ARG VERSION
ARG TEMP_DIR=/tmp/opensearch-dashboards
ARG OPENSEARCH_DASHBOARDS_HOME=/usr/share/opensearch-dashboards

ENV DEBIAN_FRONTEND=noninteractive

# Update packages and install required tools
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y tar gzip findutils npm && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Remove default ubuntu user/group (GID/UID 1000 conflict) and create opensearch-dashboards user
RUN (userdel -r ubuntu 2>/dev/null || true) && \
    (groupdel ubuntu 2>/dev/null || true) && \
    groupadd -g $GID opensearch-dashboards && \
    useradd -m -u $UID -g $GID -d $OPENSEARCH_DASHBOARDS_HOME -s /bin/bash opensearch-dashboards && \
    mkdir $TEMP_DIR

# Prepare working directory
COPY * $TEMP_DIR/
RUN tar -xzpf $TEMP_DIR/opensearch-dashboards-`uname -p`.tgz -C $OPENSEARCH_DASHBOARDS_HOME --strip-components=1 && \
    MAJOR_VERSION_ENTRYPOINT=`echo $VERSION | cut -d. -f1` && \
    MAJOR_VERSION_YML=`echo $VERSION | cut -d. -f1` && \
    echo $MAJOR_VERSION_ENTRYPOINT && echo $MAJOR_VERSION_YML && \
    if ! (ls $TEMP_DIR | grep -E "opensearch-dashboards-docker-entrypoint-.*.x.sh" | grep $MAJOR_VERSION_ENTRYPOINT); then MAJOR_VERSION_ENTRYPOINT="default"; fi && \
    if ! (ls $TEMP_DIR | grep -E "opensearch_dashboards-.*.x.yml" | grep $MAJOR_VERSION_YML); then MAJOR_VERSION_YML="default"; fi && \
    cp -v $TEMP_DIR/opensearch-dashboards-docker-entrypoint-$MAJOR_VERSION_ENTRYPOINT.x.sh $OPENSEARCH_DASHBOARDS_HOME/opensearch-dashboards-docker-entrypoint.sh && \
    cp -v $TEMP_DIR/opensearch_dashboards-$MAJOR_VERSION_YML.x.yml $OPENSEARCH_DASHBOARDS_HOME/config/opensearch_dashboards.yml && \
    cp -v $TEMP_DIR/opensearch.example.org.* $OPENSEARCH_DASHBOARDS_HOME/config/ && \
    echo "server.host: '0.0.0.0'" >> $OPENSEARCH_DASHBOARDS_HOME/config/opensearch_dashboards.yml && \
    ls -l $OPENSEARCH_DASHBOARDS_HOME && \
    rm -rf $TEMP_DIR

# Patch CVEs: Use npm to download fixed packages, then replace all vulnerable copies in-place
SHELL ["/bin/bash", "-c"]
RUN set -euo pipefail && \
    CVE_STAGING=/tmp/cve-patches && mkdir -p $CVE_STAGING && cd $CVE_STAGING && \
    npm init -y > /dev/null 2>&1 && \
    npm install --no-package-lock \
      ajv@8.18.0 \
      axios@1.13.5 \
      basic-ftp@5.2.0 \
      bn.js@4.12.3 \
      dompurify@3.3.2 \
      fast-xml-parser@5.5.6 \
      jspdf@4.2.1 \
      minimatch@3.1.4 \
      tar@7.5.11 \
      serialize-javascript@7.0.3 \
      @tootallnate/once@3.0.1 \
      @smithy/config-resolver@4.4.0 && \
    echo "Staged packages:" && npm list --depth=0 && \
    # Helper: replace_pkg <path_from_home> \
    # Surgical replacement of specific folders reported in the CVE log \
    replace_pkg() { \
      local rel_path="$1"; \
      local pkg_name=$(basename "$rel_path"); \
      # Handle scoped packages (e.g., @smithy/config-resolver) \
      if [[ "$rel_path" == *"@smithy"* ]]; then pkg_name="@smithy/config-resolver"; \
      elif [[ "$rel_path" == *"@tootallnate"* ]]; then pkg_name="@tootallnate/once"; \
      fi; \
      local source="$CVE_STAGING/node_modules/$pkg_name"; \
      local target="$OPENSEARCH_DASHBOARDS_HOME/$rel_path"; \
      if [ -d "$source" ] && [ -d "$target" ]; then \
        rm -rf "$target" && cp -a "$source" "$target" && echo "Patched: $target"; \
      else \
        echo "Skipping (not found): $target"; \
      fi; \
    } && \
    replace_pkg "node_modules/@aws-sdk/client-bedrock-runtime/node_modules/@smithy/config-resolver" && \
    replace_pkg "node_modules/@aws-sdk/token-providers/node_modules/@smithy/config-resolver" && \
    replace_pkg "node_modules/@aws-sdk/xml-builder/node_modules/fast-xml-parser" && \
    replace_pkg "node_modules/@smithy/config-resolver" && \
    replace_pkg "node_modules/ajv" && \
    replace_pkg "node_modules/asn1.js/node_modules/bn.js" && \
    replace_pkg "node_modules/axios" && \
    replace_pkg "node_modules/bn.js" && \
    replace_pkg "node_modules/dompurify" && \
    replace_pkg "node_modules/fast-xml-parser" && \
    replace_pkg "node_modules/minimatch" && \
    replace_pkg "node_modules/serialize-javascript" && \
    replace_pkg "node_modules/tar" && \
    replace_pkg "plugins/assistantDashboards/node_modules/@tootallnate/once" && \
    replace_pkg "plugins/assistantDashboards/node_modules/dompurify" && \
    replace_pkg "plugins/assistantDashboards/node_modules/minimatch" && \
    replace_pkg "plugins/investigationDashboards/node_modules/ajv" && \
    replace_pkg "plugins/investigationDashboards/node_modules/dompurify" && \
    replace_pkg "plugins/observabilityDashboards/node_modules/ajv" && \
    replace_pkg "plugins/observabilityDashboards/node_modules/dompurify" && \
    replace_pkg "plugins/reportsDashboards/node_modules/@tootallnate/once" && \
    replace_pkg "plugins/reportsDashboards/node_modules/dompurify" && \
    replace_pkg "plugins/reportsDashboards/node_modules/jspdf" && \
    replace_pkg "plugins/reportsDashboards/node_modules/minimatch" && \
    replace_pkg "plugins/securityDashboards/node_modules/basic-ftp" && \
    # Cleanup \
    rm -rf $CVE_STAGING && \
    apt-get remove -y npm && apt-get autoremove -y && apt-get clean && rm -rf /var/lib/apt/lists/* && \
    find $OPENSEARCH_DASHBOARDS_HOME -name "package-lock.json" -delete 2>/dev/null; \
    rm -rf /root/.npm /tmp/npm-*
SHELL ["/bin/sh", "-c"]

########################### Stage 1 ########################
# Copy working directory to the actual release docker images
FROM ubuntu:24.04

ARG UID=1000
ARG GID=1000
ARG OPENSEARCH_DASHBOARDS_HOME=/usr/share/opensearch-dashboards

ENV DEBIAN_FRONTEND=noninteractive

# Update packages and install required tools
RUN apt-get update -y && apt-get upgrade -y && \
    apt-get install -y tar gzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Reporting dependencies
RUN apt-get update -y && \
    apt-get install -y libnss3 xfonts-100dpi xfonts-75dpi x11-utils xfonts-cyrillic xfonts-scalable fontconfig libfreetype6 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Remove default ubuntu user/group (GID/UID 1000 conflict) and create opensearch-dashboards user
RUN (userdel -r ubuntu 2>/dev/null || true) && \
    (groupdel ubuntu 2>/dev/null || true) && \
    groupadd -g $GID opensearch-dashboards && \
    useradd -u $UID -g $GID -d $OPENSEARCH_DASHBOARDS_HOME -s /bin/bash opensearch-dashboards

COPY --from=linux_stage_0 --chown=$UID:$GID $OPENSEARCH_DASHBOARDS_HOME $OPENSEARCH_DASHBOARDS_HOME

# Setup OpenSearch-dashboards
WORKDIR $OPENSEARCH_DASHBOARDS_HOME

# Set PATH
ENV PATH=$PATH:$OPENSEARCH_DASHBOARDS_HOME/bin

# Change user
USER $UID

# Expose port
EXPOSE 5601

ARG VERSION
ARG BUILD_DATE
ARG NOTES

# Label
LABEL org.label-schema.schema-version="1.0" \
  org.label-schema.name="opensearch-dashboards" \
  org.label-schema.version="$VERSION" \
  org.label-schema.url="https://opensearch.org" \
  org.label-schema.vcs-url="https://github.com/opensearch-project/OpenSearch-Dashboards" \
  org.label-schema.license="Apache-2.0" \
  org.label-schema.vendor="OpenSearch" \
  org.label-schema.description="$NOTES" \
  org.label-schema.build-date="$BUILD_DATE" \
  "DOCKERFILE"="https://github.com/opensearch-project/opensearch-build/blob/main/docker/release/dockerfiles/opensearch-dashboards.ubuntu2404.dockerfile"

# CMD to run
ENTRYPOINT ["./opensearch-dashboards-docker-entrypoint.sh"]
CMD ["opensearch-dashboards"]
