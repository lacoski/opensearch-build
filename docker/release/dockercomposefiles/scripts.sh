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
