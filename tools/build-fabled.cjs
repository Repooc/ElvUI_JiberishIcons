// Pack approved transparent artwork without repainting it. Requires sharp.
// Usage: NODE_PATH=<path containing sharp> node tools/build-fabled.cjs
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const art = path.join(root, 'artwork/fabled');
const sources = JSON.parse(fs.readFileSync(path.join(art, 'references/blizzard-sources.json')));
const ATLAS = 2048, CELL = 256, CONTENT = 248;
const classCells = {
  warrior: [0, 0], mage: [1, 0], rogue: [2, 0], druid: [3, 0], evoker: [4, 0],
  hunter: [0, 1], shaman: [1, 1], priest: [2, 1], warlock: [3, 1],
  paladin: [0, 2], deathknight: [1, 2], monk: [2, 2], demonhunter: [3, 2],
};
const digest = data => crypto.createHash('sha256').update(data).digest('hex');
const escapeXML = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;');

// Uncompressed 32-bit BGRA TGA, top-left origin, eight alpha bits.
function tga(rgba, width, height) {
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(width, 12); header.writeUInt16LE(height, 14);
  header[16] = 32; header[17] = 0x28;
  const pixels = Buffer.from(rgba);
  for (let i = 0; i < pixels.length; i += 4) {
    pixels[i] = rgba[i + 2]; pixels[i + 2] = rgba[i];
  }
  return Buffer.concat([header, pixels]);
}

async function main() {
  fs.mkdirSync(path.join(art, 'icons'), { recursive: true });
  const manifest = { canvas: [ATLAS, ATLAS], cell: [CELL, CELL], contentMax: CONTENT,
    format: '32-bit BGRA TGA with 8-bit alpha', assets: [] };
  for (const kind of ['class', 'race']) {
    const items = sources.filter(item => item.group === kind);
    if (items.length !== (kind === 'class' ? 13 : 26)) throw Error('Unexpected roster');
    const overlays = [], preview = [];
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      const inputPath = path.join(art, 'transparent', item.id + '.png');
      const bytes = fs.readFileSync(inputPath);
      const { data, info } = await sharp(bytes).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
      let left = info.width, top = info.height, right = -1, bottom = -1, transparent = 0;
      for (let y = 0; y < info.height; y++) for (let x = 0; x < info.width; x++) {
        const alpha = data[(y * info.width + x) * 4 + 3];
        if (!alpha) transparent++;
        if (alpha > 4) { left = Math.min(left, x); right = Math.max(right, x);
          top = Math.min(top, y); bottom = Math.max(bottom, y); }
      }
      if (transparent < info.width * info.height * 0.04 || right < left) {
        throw Error(item.id + ' must have real transparency and visible artwork');
      }
      const cropped = await sharp(bytes).extract({ left, top, width: right - left + 1, height: bottom - top + 1 })
        .resize(CONTENT, CONTENT, { fit: 'inside', kernel: 'lanczos3', withoutEnlargement: true }).png().toBuffer();
      const size = await sharp(cropped).metadata();
      const tile = await sharp({ create: { width: CELL, height: CELL, channels: 4, background: '#00000000' } })
        .composite([{ input: cropped, left: Math.floor((CELL - size.width) / 2), top: Math.floor((CELL - size.height) / 2) }])
        .png().toBuffer();
      fs.writeFileSync(path.join(art, 'icons', item.id + '.png'), tile);
      const [column, row] = kind === 'class' ? classCells[item.id.slice(6)] : [index % 8, Math.floor(index / 8)];
      overlays.push({ input: tile, left: column * CELL, top: row * CELL });
      const px = (index % 7) * 170 + 21, py = Math.floor(index / 7) * 176 + 70;
      preview.push({ input: await sharp(tile).resize(128, 128).png().toBuffer(), left: px, top: py });
      preview.push({ input: Buffer.from(`<svg width="170" height="28"><text x="85" y="20" text-anchor="middle" font-family="sans-serif" font-size="13" fill="#dde4eb">${escapeXML(item.label)}</text></svg>`),
        left: (index % 7) * 170, top: py + 128 });
      manifest.assets.push({ id: item.id, label: item.label, pack: kind === 'class' ? 'fabledregalia' : 'fabledazeroth',
        cell: [column, row], bounds: [left, top, right + 1, bottom + 1], source_page: item.page,
        source_sha256: digest(bytes), icon_sha256: digest(tile) });
    }
    const pack = kind === 'class' ? 'fabledregalia' : 'fabledazeroth';
    const title = kind === 'class' ? 'Fabled Regalia' : 'Fabled Azeroth';
    const folder = path.join(root, 'ElvUI_JiberishIcons/Media', kind === 'class' ? 'Class' : 'Race');
    fs.mkdirSync(folder, { recursive: true });
    // Tiles never overlap. Copy their RGBA bytes directly so a second alpha
    // compositing pass cannot round the colors of semitransparent edge pixels.
    const rgba = Buffer.alloc(ATLAS * ATLAS * 4);
    for (const overlay of overlays) {
      const pixels = await sharp(overlay.input).ensureAlpha().raw().toBuffer();
      for (let row = 0; row < CELL; row++) {
        pixels.copy(rgba, ((overlay.top + row) * ATLAS + overlay.left) * 4, row * CELL * 4, (row + 1) * CELL * 4);
      }
    }
    const png = await sharp(rgba, { raw: { width: ATLAS, height: ATLAS, channels: 4 } }).png().toBuffer();
    fs.writeFileSync(path.join(folder, pack + '.tga'), tga(rgba, ATLAS, ATLAS));
    fs.writeFileSync(path.join(art, pack + '.png'), png);
    preview.push({ input: Buffer.from(`<svg width="1190" height="60"><text x="30" y="40" font-family="sans-serif" font-size="28" fill="#f2d5a2">${title}</text><text x="1160" y="38" text-anchor="end" font-family="sans-serif" font-size="14" fill="#aebccc">${items.length} icons · 256 × 256 source · shown at 128</text></svg>`), left: 0, top: 0 });
    await sharp({ create: { width: 1190, height: Math.ceil(items.length / 7) * 176 + 70, channels: 4, background: '#181e27' } })
      .composite(preview).png().toFile(path.join(root, 'images', title.replaceAll(' ', '') + 'WebsiteDisplay.png'));
    console.log(title + ': ' + items.length + ' icons, ' + ATLAS + ' × ' + ATLAS + ' atlas');
  }
  fs.writeFileSync(path.join(art, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
