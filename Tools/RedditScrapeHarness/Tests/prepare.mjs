import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const scriptPath = new URL('../../../Hanami/Feed Providers/Reddit/RedditWebFeedScraper+ContentScript.swift',
  import.meta.url);
const swiftSource = await readFile(scriptPath, 'utf8');
const snapshotReader = swiftSource.split('#"""')[1].split('"""#')[0];
const tests = await readFile(new URL('PostSnapshots.js', import.meta.url), 'utf8');
const outputDirectory = process.argv[2] || join(tmpdir(), 'SakuraRedditContentTests');
await mkdir(outputDirectory, { recursive: true });
await writeFile(join(outputDirectory, 'index.html'), `<!doctype html>
<meta charset="utf-8"><title>Reddit content regression tests</title><pre id="results"></pre>
<script>
window.testResults = (${tests})(${JSON.stringify(snapshotReader)});
document.querySelector('#results').textContent = JSON.stringify(window.testResults, null, 2);
document.title = window.testResults.every(result => result.passed) ? 'PASS' : 'FAIL';
</script>`);
console.log(outputDirectory);
