#!/bin/bash

# --- Configuration ---
IMAGE="opensearchproject/opensearch-dashboards:3.5.0"
SBOM_FILE="osd-sbom.json"

# Check for dependencies
if ! command -v trivy &> /dev/null || ! command -v jq &> /dev/null; then
    echo "Error: This script requires 'trivy' and 'jq'. Please install them first."
    exit 1
fi

# 1. Generate SBOM
echo "1. Generating CycloneDX SBOM for $IMAGE..."
trivy image --format cyclonedx --output "$SBOM_FILE" "$IMAGE" --quiet

# 2. Analyze and Format Output
echo "2. Analyzing SBOM for Vulnerabilities..."
echo "----------------------------------------------------------------------------------------------------------------------------------------"
printf "%-20s | %-15s | %-15s | %-18s | %-10s | %s\n" \
    "PACKAGE" "CURRENT VER" "FIXED VER" "CVE ID" "SEVERITY" "PATH"
echo "----------------------------------------------------------------------------------------------------------------------------------------"

# Use jq to extract data and pipe into a formatting loop
trivy sbom --format json "$SBOM_FILE" --quiet | jq -r '
    .Results[]? | .Vulnerabilities[]? | 
    "\(.PkgName)|\(.InstalledVersion)|\(.FixedVersion // "No Fix")|\(.VulnerabilityID)|\(.Severity)|\(.PkgPath // "N/A")"
' | while IFS="|" read -r PKG CUR FIX CVE SEV PATH; do
    printf "%-20s | %-15s | %-15s | %-18s | %-10s | %s\n" \
        "$PKG" "$CUR" "$FIX" "$CVE" "$SEV" "$PATH"
done

# 3. Final Summary
echo "----------------------------------------------------------------------------------------------------------------------------------------"
TOTAL_VULNS=$(trivy sbom --format json "$SBOM_FILE" --quiet | \
    jq '[.Results[]?.Vulnerabilities[]?] | length')

echo "Scan Complete. Total Vulnerabilities found: ${TOTAL_VULNS}"