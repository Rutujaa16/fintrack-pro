const fs = require('fs');
const html = fs.readFileSync('dashboard.html', 'utf8');
const selfClosing = new Set(['area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr','path','circle','rect','line','polyline','polygon','ellipse','stop','use']);
const rx = /<\/?([a-zA-Z][a-zA-Z0-9-]*)([^>]*)>/g;
let match;
const stack = [];
while ((match = rx.exec(html)) !== null) {
  const full = match[0];
  const tag = match[1];
  const attrs = match[2];
  const isClose = full.startsWith('</');
  const isSelf = selfClosing.has(tag.toLowerCase()) || /\/$/.test(attrs.trim());
  if (!isClose && !isSelf) {
    stack.push({tag, pos: match.index});
  } else if (isClose) {
    if (stack.length === 0) {
      console.log('Extra closing tag', tag, 'at', match.index);
      process.exit(1);
    }
    const top = stack.pop();
    if (top.tag.toLowerCase() !== tag.toLowerCase()) {
      console.log('Mismatched tag', top.tag, 'closed by', tag, 'at', match.index);
      process.exit(1);
    }
  }
}
if (stack.length > 0) {
  console.log('Unclosed tags', stack.map(x => x.tag + '@' + x.pos));
  process.exit(1);
}
console.log('Tag stack valid');
