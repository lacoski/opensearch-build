# How to Check NPM Package Versions in OpenSearch Dashboards

Since the production OpenSearch Dashboards Docker image does not include the `npm` CLI, you can use the bundled `node` binary to query package versions directly from their `package.json` files.

## 1. List All Installed Packages
To see a clean list of all installed packages (including scoped packages like `@osd/*` or `@aws-sdk/*`):

```bash
docker exec opensearch-dashboards /usr/share/opensearch-dashboards/node/bin/node -e "
const fs = require('fs');
const path = '/usr/share/opensearch-dashboards/node_modules';
fs.readdirSync(path).forEach(item => {
  if (item.startsWith('@')) {
    fs.readdirSync(path + '/' + item).forEach(sub => console.log(item + '/' + sub));
  } else if (!item.startsWith('.')) {
    console.log(item);
  }
});"
```

## 2. Check a Specific Package Version
To check the version of a specific package (e.g., `react` or `@osd/utils`), use the following command:

```bash
# Example for 'react'
docker exec opensearch-dashboards /usr/share/opensearch-dashboards/node/bin/node -p "require('/usr/share/opensearch-dashboards/node_modules/react/package.json').version"

# Example for '@osd/utils'
docker exec opensearch-dashboards /usr/share/opensearch-dashboards/node/bin/node -p "require('/usr/share/opensearch-dashboards/node_modules/@osd/utils/package.json').version"
```

## 3. List Packages with Versions
To list all packages along with their versions in a single output:

```bash
docker exec opensearch-dashboards /usr/share/opensearch-dashboards/node/bin/node -e "
const fs = require('fs');
const root = '/usr/share/opensearch-dashboards/node_modules';
const list = [];
fs.readdirSync(root).forEach(item => {
  if (item.startsWith('@')) {
    fs.readdirSync(root + '/' + item).forEach(sub => list.push(item + '/' + sub));
  } else if (!item.startsWith('.')) {
    list.push(item);
  }
});
list.forEach(pkg => {
  try {
    const version = require(root + '/' + pkg + '/package.json').version;
    console.log(pkg + '@' + version);
  } catch (e) {}
});"
```
