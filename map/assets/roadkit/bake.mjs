// Backt die Vertex-Farben der RoadKit-GLBs in eine Palette-Textur (Atlas) und
// schreibt neue GLBs mit TEXCOORD_0 + eingebetteter PNG-Textur.
// Roblox rendert keine Vertex-Farben, deshalb dieser Zwischenschritt.
import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const SRC = process.argv[2] || "C:/Users/Gio/Downloads/RoadKit/glb";
const DST = process.argv[3] || "C:/Users/Gio/Downloads/RoadKit/textured";
const MTL = path.join(path.dirname(SRC), "obj", "palette.mtl");

// ---------- Palette aus palette.mtl ----------
function loadPalette(mtlPath) {
  const text = fs.readFileSync(mtlPath, "utf8");
  const out = [];
  let cur = null;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (line.startsWith("newmtl ")) {
      cur = { name: line.slice(7).trim() };
    } else if (line.startsWith("Kd ") && cur) {
      const [r, g, b] = line.slice(3).trim().split(/\s+/).map(Number);
      cur.rgb = [r, g, b];
      out.push(cur);
      cur = null;
    }
  }
  return out;
}

// ---------- GLB lesen ----------
function readGlb(file) {
  const buf = fs.readFileSync(file);
  if (buf.readUInt32LE(0) !== 0x46546c67) throw new Error("kein GLB: " + file);
  let off = 12;
  let json = null;
  let bin = null;
  while (off < buf.length) {
    const len = buf.readUInt32LE(off);
    const type = buf.readUInt32LE(off + 4);
    const data = buf.subarray(off + 8, off + 8 + len);
    if (type === 0x4e4f534a) json = JSON.parse(data.toString("utf8"));
    else if (type === 0x004e4942) bin = data;
    off += 8 + len + ((4 - (len % 4)) % 4);
  }
  if (!json) throw new Error("kein JSON-Chunk: " + file);
  return { json, bin };
}

function readAccessor(json, bin, index) {
  const acc = json.accessors[index];
  const view = json.bufferViews[acc.bufferView];
  const compSize = { 5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4 }[acc.componentType];
  const numComp = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4 }[acc.type];
  const stride = view.byteStride || compSize * numComp;
  const base = (view.byteOffset || 0) + (acc.byteOffset || 0);
  const norm = acc.normalized === true;
  const out = new Float64Array(acc.count * numComp);
  for (let i = 0; i < acc.count; i++) {
    for (let c = 0; c < numComp; c++) {
      const p = base + i * stride + c * compSize;
      let v;
      if (acc.componentType === 5126) v = bin.readFloatLE(p);
      else if (acc.componentType === 5121) v = bin.readUInt8(p);
      else if (acc.componentType === 5123) v = bin.readUInt16LE(p);
      else if (acc.componentType === 5125) v = bin.readUInt32LE(p);
      else if (acc.componentType === 5122) v = bin.readInt16LE(p);
      else if (acc.componentType === 5120) v = bin.readInt8(p);
      else throw new Error("componentType " + acc.componentType);
      if (norm) {
        if (acc.componentType === 5121) v /= 255;
        else if (acc.componentType === 5123) v /= 65535;
        else if (acc.componentType === 5120) v = Math.max(v / 127, -1);
        else if (acc.componentType === 5122) v = Math.max(v / 32767, -1);
      }
      out[i * numComp + c] = v;
    }
  }
  return { data: out, numComp, count: acc.count };
}

// ---------- PNG schreiben ----------
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
function writePng(width, height, rgba) {
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y++) {
    raw[y * (width * 4 + 1)] = 0;
    rgba.copy(raw, y * (width * 4 + 1) + 1, y * width * 4, (y + 1) * width * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  ihdr[10] = 0;
  ihdr[11] = 0;
  ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

// ---------- Atlas bauen ----------
const CELLS = 4; // 4x4 Felder
const CELL = 256; // px pro Feld
const SIZE = CELLS * CELL;
const palette = loadPalette(MTL);
if (palette.length > CELLS * CELLS) throw new Error("Palette zu gross fuer Atlas");

const atlasPx = Buffer.alloc(SIZE * SIZE * 4);
for (let i = 0; i < CELLS * CELLS; i++) {
  const p = palette[i] || { rgb: [1, 0, 1] };
  const cx = i % CELLS;
  const cy = Math.floor(i / CELLS);
  const r = Math.round(Math.min(1, Math.max(0, p.rgb[0])) * 255);
  const g = Math.round(Math.min(1, Math.max(0, p.rgb[1])) * 255);
  const b = Math.round(Math.min(1, Math.max(0, p.rgb[2])) * 255);
  for (let y = 0; y < CELL; y++) {
    for (let x = 0; x < CELL; x++) {
      const px = cx * CELL + x;
      const py = cy * CELL + y;
      const o = (py * SIZE + px) * 4;
      atlasPx[o] = r;
      atlasPx[o + 1] = g;
      atlasPx[o + 2] = b;
      atlasPx[o + 3] = 255;
    }
  }
}
const atlasPng = writePng(SIZE, SIZE, atlasPx);

function nearestPalette(rgb) {
  let best = 0;
  let bestD = Infinity;
  for (let i = 0; i < palette.length; i++) {
    const p = palette[i].rgb;
    const d = (p[0] - rgb[0]) ** 2 + (p[1] - rgb[1]) ** 2 + (p[2] - rgb[2]) ** 2;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}
function uvFor(index) {
  const cx = (index % CELLS + 0.5) / CELLS;
  const cy = (Math.floor(index / CELLS) + 0.5) / CELLS;
  return [cx, cy];
}

// ---------- GLB neu schreiben ----------
function bakeFile(file, outFile, mirror) {
  const { json, bin } = readGlb(file);
  const prims = json.meshes.flatMap((m) => m.primitives);
  const pos = [];
  const nrm = [];
  const uv = [];
  const idx = [];
  let vbase = 0;
  let triCount = 0;

  for (const prim of prims) {
    const P = readAccessor(json, bin, prim.attributes.POSITION);
    const N = prim.attributes.NORMAL != null ? readAccessor(json, bin, prim.attributes.NORMAL) : null;
    const C = prim.attributes.COLOR_0 != null ? readAccessor(json, bin, prim.attributes.COLOR_0) : null;
    const I = prim.indices != null ? readAccessor(json, bin, prim.indices) : null;
    const triIdx = I ? I.data : Array.from({ length: P.count }, (_, i) => i);
    const triN = triIdx.length / 3;

    for (let t = 0; t < triN; t++) {
      const a = triIdx[t * 3];
      const b = triIdx[t * 3 + 1];
      const c = triIdx[t * 3 + 2];
      let rgb = [0.64, 0.64, 0.65];
      if (C) {
        const cc = C.numComp;
        rgb = [0, 0, 0];
        for (const vi of [a, b, c]) {
          rgb[0] += C.data[vi * cc] / 3;
          rgb[1] += C.data[vi * cc + 1] / 3;
          rgb[2] += C.data[vi * cc + 2] / 3;
        }
        // glTF-COLOR_0 ist linear, palette.mtl (Kd) ist sRGB -> umrechnen
        const toSrgb = (l) => (l <= 0.0031308 ? 12.92 * l : 1.055 * Math.pow(l, 1 / 2.4) - 0.055);
        rgb = rgb.map(toSrgb);
      }
      const pIdx = nearestPalette(rgb);
      const uvc = uvFor(pIdx);
      // Spiegelung: X negieren und Windung umdrehen, sonst zeigen die Normalen nach innen
      const order = mirror ? [c, b, a] : [a, b, c];
      for (const vi of order) {
        pos.push(mirror ? -P.data[vi * 3] : P.data[vi * 3], P.data[vi * 3 + 1], P.data[vi * 3 + 2]);
        if (N) nrm.push(mirror ? -N.data[vi * 3] : N.data[vi * 3], N.data[vi * 3 + 1], N.data[vi * 3 + 2]);
        else nrm.push(0, 1, 0);
        uv.push(uvc[0], uvc[1]);
        idx.push(vbase++);
      }
      triCount++;
    }
  }

  const posBuf = Buffer.alloc(pos.length * 4);
  pos.forEach((v, i) => posBuf.writeFloatLE(v, i * 4));
  const nrmBuf = Buffer.alloc(nrm.length * 4);
  nrm.forEach((v, i) => nrmBuf.writeFloatLE(v, i * 4));
  const uvBuf = Buffer.alloc(uv.length * 4);
  uv.forEach((v, i) => uvBuf.writeFloatLE(v, i * 4));
  const idxBuf = Buffer.alloc(idx.length * 4);
  idx.forEach((v, i) => idxBuf.writeUInt32LE(v, i * 4));

  const parts = [];
  let off = 0;
  const add = (buf) => {
    const pad = (4 - (off % 4)) % 4;
    if (pad) {
      parts.push(Buffer.alloc(pad));
      off += pad;
    }
    const view = { buffer: 0, byteOffset: off, byteLength: buf.length };
    parts.push(buf);
    off += buf.length;
    return view;
  };
  const vPos = add(posBuf);
  const vNrm = add(nrmBuf);
  const vUv = add(uvBuf);
  const vIdx = add(idxBuf);
  const vPng = add(atlasPng);
  const binOut = Buffer.concat(parts);
  const padBin = (4 - (binOut.length % 4)) % 4;
  const binFinal = padBin ? Buffer.concat([binOut, Buffer.alloc(padBin)]) : binOut;

  const vertexCount = pos.length / 3;
  const min = [Infinity, Infinity, Infinity];
  const max = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < vertexCount; i++) {
    for (let c = 0; c < 3; c++) {
      const v = pos[i * 3 + c];
      if (v < min[c]) min[c] = v;
      if (v > max[c]) max[c] = v;
    }
  }

  const gltf = {
    asset: { version: "2.0", generator: "roadkit-bake" },
    scene: 0,
    scenes: [{ nodes: [0] }],
    nodes: [{ mesh: 0, name: path.basename(outFile, ".glb") }],
    meshes: [{ name: path.basename(outFile, ".glb"), primitives: [{ attributes: { POSITION: 0, NORMAL: 1, TEXCOORD_0: 2 }, indices: 3, material: 0 }] }],
    materials: [
      {
        name: "RoadKit_Palette",
        pbrMetallicRoughness: {
          baseColorTexture: { index: 0 },
          metallicFactor: 0,
          roughnessFactor: 0.95,
        },
      },
    ],
    textures: [{ sampler: 0, source: 0 }],
    samplers: [{ magFilter: 9728, minFilter: 9728, wrapS: 33071, wrapT: 33071 }],
    images: [{ bufferView: 4, mimeType: "image/png" }],
    accessors: [
      { bufferView: 0, componentType: 5126, count: vertexCount, type: "VEC3", min, max },
      { bufferView: 1, componentType: 5126, count: vertexCount, type: "VEC3" },
      { bufferView: 2, componentType: 5126, count: vertexCount, type: "VEC2" },
      { bufferView: 3, componentType: 5125, count: idx.length, type: "SCALAR" },
    ],
    bufferViews: [
      { ...vPos, target: 34962 },
      { ...vNrm, target: 34962 },
      { ...vUv, target: 34962 },
      { ...vIdx, target: 34963 },
      { ...vPng },
    ],
    buffers: [{ byteLength: binFinal.length }],
  };

  let jsonBuf = Buffer.from(JSON.stringify(gltf), "utf8");
  const jsonPad = (4 - (jsonBuf.length % 4)) % 4;
  if (jsonPad) jsonBuf = Buffer.concat([jsonBuf, Buffer.alloc(jsonPad, 0x20)]);

  const header = Buffer.alloc(12);
  header.writeUInt32LE(0x46546c67, 0);
  header.writeUInt32LE(2, 4);
  header.writeUInt32LE(12 + 8 + jsonBuf.length + 8 + binFinal.length, 8);
  const jsonHead = Buffer.alloc(8);
  jsonHead.writeUInt32LE(jsonBuf.length, 0);
  jsonHead.writeUInt32LE(0x4e4f534a, 4);
  const binHead = Buffer.alloc(8);
  binHead.writeUInt32LE(binFinal.length, 0);
  binHead.writeUInt32LE(0x004e4942, 4);

  fs.writeFileSync(outFile, Buffer.concat([header, jsonHead, jsonBuf, binHead, binFinal]));
  return { tris: triCount, verts: vertexCount, size: fs.statSync(outFile).size };
}

// ---------- Durchlauf ----------
fs.mkdirSync(DST, { recursive: true });
fs.writeFileSync(path.join(DST, "_palette.png"), atlasPng);
console.log("Palette:", palette.map((p) => p.name).join(", "));
// Kurven gibt es im Kit nur als Linkskurve -> gespiegelte Variante fuer Rechtskurven
const MIRROR = ["Road_Curve90_8x8", "Road_Curve45_R16"];
let n = 0;
for (const f of fs.readdirSync(SRC).filter((f) => f.endsWith(".glb") && !f.includes("Showcase"))) {
  const r = bakeFile(path.join(SRC, f), path.join(DST, f));
  console.log(`${f.padEnd(32)} tris=${String(r.tris).padEnd(5)} verts=${String(r.verts).padEnd(5)} ${(r.size / 1024).toFixed(1)} KB`);
  n++;
  const base = path.basename(f, ".glb");
  if (MIRROR.includes(base)) {
    const mf = base + "_Mirror.glb";
    const r2 = bakeFile(path.join(SRC, f), path.join(DST, mf), true);
    console.log(`${mf.padEnd(32)} tris=${String(r2.tris).padEnd(5)} verts=${String(r2.verts).padEnd(5)} ${(r2.size / 1024).toFixed(1)} KB  (gespiegelt)`);
    n++;
  }
}
console.log(`FERTIG: ${n} Dateien in ${DST}`);
