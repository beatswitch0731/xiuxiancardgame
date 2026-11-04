// Rebuild DATA_MODULES in index.html from JSON data files
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const indexFile = path.join(ROOT, 'index.html');
const dataDir = path.join(ROOT, 'data');

function listJsonFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const full = path.join(dir, entry.name);
    return entry.isDirectory() ? listJsonFiles(full) : (entry.name.endsWith('.json') ? [full] : []);
  });
}

// data/ 是唯一维护源；内联 DATA_MODULES 只由本脚本机械生成。
const moduleMap = {};
for (const file of listJsonFiles(dataDir)) {
  const relative = path.relative(dataDir, file).replace(/\\/g, '/').replace(/\.json$/, '');
  let moduleName = relative.replace(/\//g, ':');
  if (relative === 'npcs/core_npcs') moduleName = 'npcs:core';
  moduleMap[moduleName] = file;
}

// Read all modules
const DATA_MODULES = {};
for (const [name, file] of Object.entries(moduleMap)) {
  try {
    DATA_MODULES[name] = JSON.parse(fs.readFileSync(file, 'utf-8'));
    console.log('  OK: ' + name + ' ← ' + path.relative(ROOT, file));
  } catch (e) {
    console.log('  ERROR: ' + name + ' ← ' + file + ' — ' + e.message);
    process.exit(1);
  }
}

// Read index.html
let html = fs.readFileSync(indexFile, 'utf-8');

// Replace DATA_MODULES block
const re = /const DATA_MODULES\s*=\s*\{.+?\};/s;
const replacement = 'const DATA_MODULES = ' + JSON.stringify(DATA_MODULES) + ';';

if (!re.test(html)) {
  console.log('ERROR: Could not find DATA_MODULES in index.html');
  process.exit(1);
}

html = html.replace(re, replacement);

// Write back
fs.writeFileSync(indexFile, html, 'utf-8');
console.log('\nDone! DATA_MODULES rebuilt with ' + Object.keys(DATA_MODULES).length + ' modules.');
const size = (Buffer.byteLength(JSON.stringify(DATA_MODULES)) / 1024).toFixed(1);
console.log('Data size: ~' + size + ' KB');
