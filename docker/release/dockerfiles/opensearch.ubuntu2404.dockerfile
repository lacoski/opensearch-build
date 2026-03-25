# Copyright OpenSearch Contributors
# SPDX-License-Identifier: Apache-2.0

# This dockerfile generates an Ubuntu-based image containing an OpenSearch installation.
# It assumes that the working directory contains these files: an OpenSearch tarball (opensearch.tgz), log4j2.properties, opensearch.yml, opensearch-docker-entrypoint.sh, opensearch-onetime-setup.sh.

########################### Stage 0 ########################
FROM ubuntu:24.04 AS linux_stage_0

ARG UID=1000
ARG GID=1000
ARG VERSION
ARG TEMP_DIR=/tmp/opensearch
ARG OPENSEARCH_HOME=/usr/share/opensearch
ARG OPENSEARCH_PATH_CONF=$OPENSEARCH_HOME/config
ARG SECURITY_PLUGIN_DIR=$OPENSEARCH_HOME/plugins/opensearch-security
ARG PERFORMANCE_ANALYZER_PLUGIN_CONFIG_DIR=$OPENSEARCH_PATH_CONF/opensearch-performance-analyzer

# Update packages and install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends tar gzip ca-certificates curl findutils unzip zip which && \
    rm -rf /var/lib/apt/lists/*

# Create an opensearch user, group, and directory
RUN if ! getent group $GID; then groupadd -g $GID opensearch; else groupmod -n opensearch $(getent group $GID | cut -d: -f1); fi && \
    if ! getent passwd $UID; then useradd -u $UID -g $GID -d $OPENSEARCH_HOME -s /bin/bash opensearch; else usermod -l opensearch -d $OPENSEARCH_HOME -g $GID $(getent passwd $UID | cut -d: -f1); fi && \
    mkdir -p $TEMP_DIR

# Prepare working directory
COPY * $TEMP_DIR/
RUN ls -l $TEMP_DIR && \
    mkdir -p $OPENSEARCH_HOME && \
    # Unpack the tarball. The build script renames the input tarball to opensearch-$(uname -p).tgz
    tar -xzpf $TEMP_DIR/opensearch-$(uname -m | sed 's/x86_64/x86_64/;s/aarch64/aarch64/').tgz -C $OPENSEARCH_HOME --strip-components=1 && \
    # Fix High CVEs (incorporating fixes identified for OpenSearch 3.5.0)
    curl -L https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.21.1/jackson-core-2.21.1.jar -o /tmp/jackson-core-2.21.1.jar && \
    curl -L https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.21.1/jackson-databind-2.21.1.jar -o /tmp/jackson-databind-2.21.1.jar && \
    curl -L https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.21/jackson-annotations-2.21.jar -o /tmp/jackson-annotations-2.21.jar && \
    curl -L https://repo1.maven.org/maven2/org/apache/spark/spark-core_2.13/3.5.7/spark-core_2.13-3.5.7.jar -o /tmp/spark-core_2.13-3.5.7.jar && \
    find $OPENSEARCH_HOME -name "jackson-core-2.*.jar" -exec sh -c 'cp /tmp/jackson-core-2.21.1.jar $(dirname $1)/jackson-core-2.21.1.jar && rm $1' _ {} \; && \
    find $OPENSEARCH_HOME -name "jackson-databind-2.*.jar" -exec sh -c 'cp /tmp/jackson-databind-2.21.1.jar $(dirname $1)/jackson-databind-2.21.1.jar && rm $1' _ {} \; && \
    find $OPENSEARCH_HOME -name "jackson-annotations-2.*.jar" -exec sh -c 'cp /tmp/jackson-annotations-2.21.jar $(dirname $1)/jackson-annotations-2.21.jar && rm $1' _ {} \; && \
    find $OPENSEARCH_HOME -name "spark-core_2.13-3.5.4.jar" -exec sh -c 'cp /tmp/spark-core_2.13-3.5.7.jar $(dirname $1)/spark-core_2.13-3.5.7.jar && rm $1' _ {} \; && \
    # Remove vulnerable shaded jackson classes from opensaml jar to fix CVEs and prevent jar hell
    OPENSAML_JAR=$(find $OPENSEARCH_HOME -name "opensaml-3.5.0.0-all.jar") && \
    if [ -f "$OPENSAML_JAR" ]; then \
      zip -d "$OPENSAML_JAR" "com/fasterxml/jackson/*" "META-INF/versions/*/com/fasterxml/jackson/*" "META-INF/maven/com.fasterxml.jackson.core/*" "META-INF/maven/com.fasterxml.jackson.datatype/*" || true; \
    fi && \
    MAJOR_VERSION_ENTRYPOINT=$(echo $VERSION | cut -d. -f1) && \
    if ! (ls $TEMP_DIR | grep -E "opensearch-docker-entrypoint-.*.x.sh" | grep $MAJOR_VERSION_ENTRYPOINT); then MAJOR_VERSION_ENTRYPOINT="default"; fi && \
    mkdir -p $OPENSEARCH_HOME/data && chown -Rv $UID:$GID $OPENSEARCH_HOME/data && \
    if [ -d "$SECURITY_PLUGIN_DIR" ] ; then chmod -v 750 $SECURITY_PLUGIN_DIR/tools/* ; fi && \
    if [ -d "$PERFORMANCE_ANALYZER_PLUGIN_CONFIG_DIR" ] ; then cp -v $TEMP_DIR/performance-analyzer.properties $PERFORMANCE_ANALYZER_PLUGIN_CONFIG_DIR; fi && \
    cp -v $TEMP_DIR/opensearch-docker-entrypoint-$MAJOR_VERSION_ENTRYPOINT.x.sh $OPENSEARCH_HOME/opensearch-docker-entrypoint.sh && \
    cp -v $TEMP_DIR/opensearch-onetime-setup.sh $OPENSEARCH_HOME/ && \
    cp -v $TEMP_DIR/log4j2.properties $TEMP_DIR/opensearch.yml $OPENSEARCH_PATH_CONF/ && \
    rm -rf $TEMP_DIR


########################### Stage 1 ########################
FROM ubuntu:24.04

ARG UID=1000
ARG GID=1000
ARG OPENSEARCH_HOME=/usr/share/opensearch

# Update packages and install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends tar gzip ca-certificates curl findutils unzip zip which && \
    rm -rf /var/lib/apt/lists/*

# Create an opensearch user and group
RUN if ! getent group $GID; then groupadd -g $GID opensearch; else groupmod -n opensearch $(getent group $GID | cut -d: -f1); fi && \
    if ! getent passwd $UID; then useradd -u $UID -g $GID -d $OPENSEARCH_HOME opensearch; else usermod -l opensearch -d $OPENSEARCH_HOME -g $GID $(getent passwd $UID | cut -d: -f1); fi

# Copy from Stage0
COPY --from=linux_stage_0 --chown=$UID:$GID $OPENSEARCH_HOME $OPENSEARCH_HOME
WORKDIR $OPENSEARCH_HOME

# Set $JAVA_HOME
RUN echo "export JAVA_HOME=$OPENSEARCH_HOME/jdk" >> /etc/profile.d/java_home.sh && \
    echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/profile.d/java_home.sh

ENV JAVA_HOME=$OPENSEARCH_HOME/jdk
ENV PATH=$PATH:$JAVA_HOME/bin:$OPENSEARCH_HOME/bin
ENV LD_LIBRARY_PATH="$OPENSEARCH_HOME/plugins/opensearch-knn/lib"

# Change user
USER $UID

# Setup OpenSearch
ARG DISABLE_INSTALL_DEMO_CONFIG=true
ARG DISABLE_SECURITY_PLUGIN=false
RUN ./opensearch-onetime-setup.sh

# Expose ports
EXPOSE 9200 9300 9600 9650

ARG VERSION
ARG BUILD_DATE
ARG NOTES

# Label
LABEL org.label-schema.schema-version="1.0" \
  org.label-schema.name="opensearch" \
  org.label-schema.version="$VERSION" \
  org.label-schema.url="https://opensearch.org" \
  org.label-schema.vcs-url="https://github.com/opensearch-project/OpenSearch" \
  org.label-schema.license="Apache-2.0" \
  org.label-schema.vendor="OpenSearch" \
  org.label-schema.description="$NOTES" \
  org.label-schema.build-date="$BUILD_DATE"

# CMD to run
ENTRYPOINT ["./opensearch-docker-entrypoint.sh"]
CMD ["opensearch"]
