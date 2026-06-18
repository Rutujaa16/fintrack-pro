const fs = require('fs');
const text = fs.readFileSync('dashboard.html', 'utf8');
const lines = text.split(/\r?\n/);
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const quoteCount = (line.match(/"/g) || []).length;
  if (quoteCount % 2 !== 0) {
    console.log(`Line ${i+1} has odd quote count: ${quoteCount}`);
    console.log(line);
  }
}
console.log('Done quote check');
