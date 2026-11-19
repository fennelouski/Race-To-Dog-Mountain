/** Reproducible App Store artwork. Native captures are embedded without repainting their UI. */
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
const require=createRequire(import.meta.url);
let sharp; try { sharp=require('sharp'); } catch { sharp=require(path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp')); }
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const input=path.join(root,'Release/Marketing/Screenshots');
const output=path.join(root,'Release/Marketing/AppStore');
const specs=[
 ['01-every-choice',4,['One number.','So many possibilities.'],'Take the points. Shape the next turn.'],
 ['02-first-tangle',5,['Small board.','Big decisions.'],'Find your rhythm, one move at a time.'],
 ['03-your-rival',6,['Meet your','next challenge.'],'18 computer rivals. A level for every player.'],
 ['04-together',9,['Your move.','Their next problem.'],'Two players. One very clever tangle.'],
 ['05-think-ahead',10,['The biggest number','is only the beginning.'],'Choose the line your rival has to play.'],
 ['06-the-finish',13,['Make every','point count.'],'Plan a path to the higher score.'],
 ['07-replay',24,['See the move.','Find the idea.'],'Replay. Look closer. Try another route.'],
 ['08-more-to-explore',27,['A bigger board.','A deeper tangle.'],'Choose your board. Grow your strategy.'],
 ['09-your-game',18,['A little more','you.'],'Set up the next game your way.'],
 ['10-step-inside',1,['Welcome to','your next obsession.'],'A living garden of number strategy.']
];
const esc=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const wrapCache=new Map();
async function wrap(text,width,size,bold=false){
 const key=`${bold}:${Math.round(width/size*100000)}:${text}`;
 if(wrapCache.has(key))return wrapCache.get(key);
 const lines=[];let line='';
 for(const word of text.split(' ')){
  const trial=line?line+' '+word:word;
  const m=await sharp({text:{text:esc(trial),font:`${bold?'Georgia Bold':'Helvetica Neue'} ${size}`,dpi:72}}).metadata();
  if(line&&m.width>width){lines.push(line);line=word;}else{line=trial;}
 }
 if(line)lines.push(line);wrapCache.set(key,lines);return lines;
}
const manifest={created:'2026-11-17',language:'en-US',method:'Editable SVG compositions with embedded authentic native captures. Screenshots are proportionally scaled, never repainted. Promotional efficacy is a creative hypothesis, not measured conversion evidence.',families:[]};
for(const family of (await fs.readdir(input)).sort()){
 const dir=path.join(input,family);if(!(await fs.stat(dir)).isDirectory())continue;
 try{await Promise.all(specs.map(([,scene])=>fs.access(path.join(dir,`${String(scene).padStart(2,'0')}.png`))));}catch{continue;}
 const meta=await sharp(path.join(dir,'04.png')).metadata();const W=meta.width,H=meta.height;
 const landscape=W>H;const out=path.join(output,family);await fs.mkdir(out,{recursive:true});
 const files=[];
 for(let i=0;i<specs.length;i++){
  const [name,scene,lines,subtitle]=specs[i];const native=await fs.readFile(path.join(dir,`${String(scene).padStart(2,'0')}.png`));
  const nativeMeta=await sharp(native).metadata();
  const light=[1,5,8].includes(i), warm=i===3||i===9;
  const bg=light?'#fff1d1':warm?'#154942':'#071f2a',ink=light?'#092b31':'#fff1d1',accent=i%2?'#72dace':'#ffbc48';
  let art='';
  // An original botanical frame extends the game's established vine identity.
  for(let v=0;v<8;v++){
   const x=W*(0.06+v*.15),y=H*(v%2?0.97:0.02),sign=v%2?-1:1;
   art+=`<g opacity="${light?.11:.18}" fill="none" stroke="${light?'#22634c':'#80c76b'}" stroke-width="${W*.003}"><path d="M ${x} ${y} q ${W*.1} ${H*.06*sign} ${W*.04} ${H*.17*sign}"/></g>`;
   for(let l=0;l<4;l++)art+=`<ellipse cx="${x+Math.sin(l+v)*W*.035}" cy="${y+sign*H*(.03+l*.035)}" rx="${W*.014}" ry="${W*.006}" transform="rotate(${l*23+v*10} ${x} ${y})" fill="${accent}" opacity=".13"/>`;
  }
  const margin=W*.065;const fsTitle=landscape?W*.044:W*.078;
  let textX=margin,textY=landscape?H*.23:H*.145;
  let box=landscape?{x:W*.385,y:H*.12,w:W*.57,h:H*.77}:{x:W*.075,y:H*.32,w:W*.85,h:H*.635};
  // Alternating wide compositions give the board priority, while the series stays recognizable.
  if(landscape&&i%3===1){box={x:W*.045,y:H*.12,w:W*.57,h:H*.77};textX=W*.66;}
  const titleLines=[]; for(const line of lines)titleLines.push(...await wrap(line,landscape?W*.275:W*.87,fsTitle,true));
  const title=titleLines.map((line,j)=>`<text x="${textX}" y="${textY+j*fsTitle*1.14}" fill="${ink}" font-size="${fsTitle}" font-weight="700" font-family="Georgia">${esc(line)}</text>`).join('');
  const sub=await wrap(subtitle,landscape?W*.265:W*.87,landscape?W*.018:W*.029);
  const subY=textY+titleLines.length*fsTitle*1.14+H*.035;
  if(!landscape){
   // Reserve the measured caption block before positioning the screenshot frame.
   box.y=Math.max(box.y,subY+(sub.length-1)*H*.04+W*.029*.4+H*.035+W*.008);
   box.h=H*.955-box.y;
  }
  const scale=Math.min(box.w/nativeMeta.width,box.h/nativeMeta.height),sw=nativeMeta.width*scale,sh=nativeMeta.height*scale;
  const sx=box.x+(box.w-sw)/2,sy=box.y+(box.h-sh)/2;
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
  <rect width="${W}" height="${H}" fill="${bg}"/>${art}
  <text x="${margin}" y="${H*.055}" font-family="Helvetica Neue,Arial" font-weight="700" font-size="${W*.022}" letter-spacing="${W*.003}" fill="${ink}">TALLY TANGLE</text>
  <rect x="${textX}" y="${textY-fsTitle*1.1}" width="${W*.06}" height="${H*.005}" rx="3" fill="${accent}"/>
  ${title}${sub.map((line,j)=>`<text x="${textX}" y="${subY+j*H*.04}" fill="${ink}" font-size="${landscape?W*.018:W*.029}" font-family="Helvetica Neue,Arial">${esc(line)}</text>`).join('')}
  <rect x="${sx-W*.008}" y="${sy-W*.008}" width="${sw+W*.016}" height="${sh+W*.016}" rx="${W*.012}" fill="#071f2a" stroke="${accent}" stroke-width="${W*.0016}"/>
  <image href="data:image/png;base64,${native.toString('base64')}" x="${sx}" y="${sy}" width="${sw}" height="${sh}"/>
  </svg>`;
  const png=await sharp(Buffer.from(svg)).flatten({background:bg}).png().toBuffer();
  await fs.writeFile(path.join(out,`${name}.png`),png);await fs.writeFile(path.join(out,`${name}.svg`),svg);
  files.push({file:`${family}/${name}.png`,width:W,height:H,copy:[...lines,subtitle],source:`Screenshots/${family}/${String(scene).padStart(2,'0')}.png`,sourceSHA256:hash(native),SHA256:hash(png)});
 }
 manifest.families.push({family,files});console.log(`Rendered ${family}: ${files.length} images (${W}×${H})`);
}
await fs.mkdir(output,{recursive:true});await fs.writeFile(path.join(output,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
