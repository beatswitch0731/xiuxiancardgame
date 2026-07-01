const fs = require('fs');
let html = fs.readFileSync('index.html', 'utf8');

const dmStart = html.indexOf('const DATA_MODULES');
const eqIdx = html.indexOf('=', dmStart) + 1;
const openBrace = html.indexOf('{', eqIdx);
let depth = 0, endIdx = -1;
for (let i = openBrace; i < html.length; i++) {
  if (html[i] === '{') depth++;
  else if (html[i] === '}') { depth--; if (depth === 0) { endIdx = html.indexOf(';', i); break; } }
}
const block = html.substring(openBrace, endIdx);

let fixed = block;

// Fix pattern: value-end immediately followed by key-start without comma
// Case A: number/bool/null followed by "key":  e.g., 0"tags":
fixed = fixed.replace(/([0-9etnf])"([a-z_][a-zA-Z0-9_]*)"(\s*:)/g, '$1,"$2"$3');

// Case B: ] or } followed by "key":
fixed = fixed.replace(/([\]}])"([a-z_][a-zA-Z0-9_]*)"(\s*:)/g, '$1,"$2"$3');

// Count remaining issues
const remaining = (fixed.match(/([a-zA-Z0-9"})\]])"([a-z_])/g) || []).length;
console.log('Same-line missing commas remaining:', remaining);

html = html.substring(0, openBrace) + fixed + html.substring(endIdx);
fs.writeFileSync('index.html', html);

// Validate
try {
  JSON.parse(fixed.trim());
  console.log('✅ DATA_MODULES PARSE OK');
} catch(e) {
  console.log('❌ Error:', e.message.substring(0,120));
  const m = e.message.match(/position (\d+)/);
  if (m) {
    const pos = parseInt(m[1]);
    const ctx = fixed.trim().substring(Math.max(0, pos-80), pos+80);
    console.log('Context:', JSON.stringify(ctx));
    // Show line
    const lines = fixed.trim().substring(0, pos).split('\n');
    console.log('Line:', lines.length, 'Last line:', lines[lines.length-1]);
  }
}
