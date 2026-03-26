Reference
- @how-to-build-opensearch-dashboard.md
- @trivy-detech-cves.log
- @docker/release/dockerfiles/opensearch-dashboards.ubuntu2404.dockerfile

requirements
- only patch folder and files have cves from trivy-detech-cves.log

implementation
- 1. run scan-trivy-community-images.sh to generate trivy-detech-cves.log
- 2. using trivy-detech-cves.log to patch packages @docker/release/dockerfiles/opensearch-dashboards.ubuntu2404.dockerfile
- 3. build image
- 4. after build, using @/home/ubuntu/opensearch/opensearch-build/scan-trivy-community-images.sh to scan new build image