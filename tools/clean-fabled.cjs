// Local background extraction authorized by the user. Needs Sharp and the
// compiled foreground-fabled.swift helper (path passed as the first argument).
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..', 'artwork/fabled');
const helper = process.argv[2] || '/tmp/fabled-foreground';
const sources = JSON.parse(fs.readFileSync(path.join(root, 'references/blizzard-sources.json')));
const percentile = (values, p) => values.sort((a, b) => a - b)[Math.floor((values.length - 1) * p)];

async function main() {
  for (const dir of ['masked', 'transparent']) fs.mkdirSync(path.join(root, dir), { recursive: true });
  const report = [];
  for (const item of sources) {
    const input = path.join(root, 'originals', item.id + '.png');
    const output = path.join(root, 'transparent', item.id + '.png');
    const meta = await sharp(input).metadata();
    const stats = meta.hasAlpha && await sharp(input).stats();
    if (stats && stats.channels[3].min === 0) {
      fs.copyFileSync(input, output);
      report.push({ id: item.id, method: 'Preserved original alpha' });
      continue;
    }
    const masked = path.join(root, 'masked', item.id + '.png');
    if (!fs.existsSync(masked)) {
      const result = spawnSync(helper, [input, masked], { encoding: 'utf8' });
      if (result.status !== 0) throw Error(result.stderr || 'Foreground extraction failed');
    }
    const { data: original, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    const data = await sharp(masked).ensureAlpha().raw().toBuffer();
    const count = info.width * info.height, light = [], chroma = [];
    for (let y = 0; y < 60; y++) for (let x = 0; x < 60; x++) {
      for (const px of [x, info.width - 1 - x]) {
        const i = (y * info.width + px) * 4;
        const rgb = original.subarray(i, i + 3);
        light.push((rgb[0] + rgb[1] + rgb[2]) / 3);
        chroma.push(Math.max(...rgb) - Math.min(...rgb));
      }
    }
    const black = percentile(light, .99) < 20;
    const minLight = black ? 0 : percentile(light, .01) - 16;
    const maxLight = black ? 20 : percentile(light, .99) + 16;
    const maxChroma = Math.min(14, percentile(chroma, .99) + 6);
    // Vision preserves the silhouette but can leave a narrow checkerboard rim.
    // Flood only matching neutral background pixels connected to its exterior;
    // dark outlines and colored artwork stop the flood.
    const visited = new Uint8Array(count), queue = new Int32Array(count);
    let head = 0, tail = 0, removed = 0;
    for (let p = 0; p < count; p++) if (data[p * 4 + 3] < 3) {
      visited[p] = 1; queue[tail++] = p; data[p * 4 + 3] = 0;
    }
    const visit = p => {
      if (visited[p]) return;
      visited[p] = 1;
      const i = p * 4, r = original[i], g = original[i + 1], b = original[i + 2];
      const lum = (r + g + b) / 3;
      if (lum >= minLight && lum <= maxLight && Math.max(r, g, b) - Math.min(r, g, b) <= maxChroma) {
        data[i + 3] = 0; queue[tail++] = p; removed++;
      }
    };
    while (head < tail) {
      const p = queue[head++], x = p % info.width;
      if (x) visit(p - 1);
      if (x < info.width - 1) visit(p + 1);
      if (p >= info.width) visit(p - info.width);
      if (p < count - info.width) visit(p + info.width);
    }
    // Retain exact original RGB wherever alpha survives.
    for (let p = 0; p < count; p++) {
      const i = p * 4;
      for (let c = 0; c < 3; c++) data[i + c] = data[i + 3] ? original[i + c] : 0;
    }
    await sharp(data, { raw: { width: info.width, height: info.height, channels: 4 } }).png().toFile(output);
    report.push({ id: item.id, method: 'macOS Vision foreground mask and connected neutral-background cleanup',
      background: black ? 'black' : 'checkerboard', removedRimPixels: removed, minLight, maxLight, maxChroma });
    console.log(item.id + ': cleaned');
  }
  fs.writeFileSync(path.join(root, 'cleanup-report.json'), JSON.stringify(report, null, 2) + '\n');
  console.log(report.length + ' transparent masters ready');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
