import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import sharp from '/Users/nathan/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp/dist/index.mjs';
const dir = path.dirname(new URL(import.meta.url).pathname);
const raw = '/Users/nathan/Documents/GitHub/app-store-audit/2026-09-30-race-2.1-build7/raw';
const uri = async p => `data:image/png;base64,${(await fs.readFile(p)).toString('base64')}`;
const background = await uri(path.join(dir,'alpine-backdrop.png'));
const panels = [
 ['game','Every move','shapes the climb.','Classic strategy. You move first.'],
 ['home','Meet your','next rival.','16 levels. 16 named opponents.'],
 ['replay','Watch the','clever moves.','Replay your rival’s last move.']
];
const manifest = {version:'2.1',build:7,method:'New SVG layouts: generated background, native screenshots embedded unchanged, exact typeset copy. No invented UI.',files:[]};
for (const [family,W,H,sw,y] of [['phone',1320,2868,980,615],['tablet',2064,2752,1460,660]]) {
 const tablet=family==='tablet'; const font=tablet?145:119; const x=tablet?165:100;
 for(let i=0;i<panels.length;i++){
  const [state,line1,line2,sub]=panels[i]; const p=path.join(raw,`${family}-${state}.png`);
  const meta=await sharp(p).metadata(); const sh=sw*meta.height/meta.width; const sx=(W-sw)/2;
  const screenshot=await uri(p);
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
 <image href="${background}" width="${W}" height="${H}" preserveAspectRatio="xMidYMid slice"/>
 <rect width="${W}" height="620" fill="#06202B" fill-opacity=".28"/>
 <text x="${x}" y="${tablet?300:290}" fill="#FFF2D1" font-family="Georgia" font-size="${font}" font-weight="700" letter-spacing="-3">${line1}</text>
 <text x="${x}" y="${tablet?465:430}" fill="#FFF2D1" font-family="Georgia" font-size="${font}" font-weight="700" letter-spacing="-3">${line2}</text>
 <text x="${x}" y="${tablet?558:525}" fill="#FFF2D1" font-family="Helvetica Neue,Arial" font-size="${tablet?46:39}">${sub}</text>
 <rect x="${sx-13}" y="${y-13}" width="${sw+26}" height="${sh+26}" rx="22" fill="#06202B" stroke="#FFC04B" stroke-opacity=".65" stroke-width="3"/>
 <image href="${screenshot}" x="${sx}" y="${y}" width="${sw}" height="${sh}"/>
 </svg>`;
  const name=`${family}-${String(i+1).padStart(2,'0')}-${state}`;
  await sharp(Buffer.from(svg)).flatten({background:'#06202B'}).png().toFile(path.join(dir,`${name}.png`));
  manifest.files.push({file:`${name}.png`,width:W,height:H,capture:p,captureSHA256:crypto.createHash('sha256').update(await fs.readFile(p)).digest('hex'),copy:[line1,line2,sub]});
 }
}
await fs.writeFile(path.join(dir,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
console.log('Rendered six App Store screenshots from verified native captures.');
