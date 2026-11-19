/** Discovery artwork extends the existing editable SVG system using authentic game assets. */
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
let sharp;try{sharp=require('sharp')}catch{sharp=require(path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'))}
const root=path.resolve(import.meta.dirname,'../..'),out=path.join(root,'Release/Marketing/Discovery');await fs.mkdir(out,{recursive:true});
const sources=['Release/Marketing/Screenshots/mac/04.png','Tally Tangle/Images.xcassets/Opponent1.imageset/portrait.png','Tally Tangle/Images.xcassets/Opponent16.imageset/portrait.png'];
const data=await Promise.all(sources.map(f=>fs.readFile(path.join(root,f))));
const uri=i=>'data:image/png;base64,'+data[i].toString('base64');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const manifest={date:'2026-11-18',uploadStatus:'Prepared locally; browser connection unavailable',specification:'https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications',method:'Editable SVG composition with a proportionally scaled crop of a real 6x6 gameplay board and shipped rival portraits. No invented game state, English caption, device frame, price, or download claim.',sources:sources.map((file,i)=>({file,sha256:hash(data[i])})),assets:[]};
for(const spec of [{name:'header',w:3840,h:1646,safe:[1097,493,1646,661],board:620,portrait:300,gap:120},{name:'search-results',w:3840,h:2560,safe:[836,765,2168,1030],board:960,portrait:400,gap:150}]){
 const {w,h,board:b,portrait:p,gap:g}=spec,cx=w/2,cy=h/2;
 const bx=cx-b/2,by=cy-b/2;
 let botanicals='';
 for(let side of [-1,1])for(let n=0;n<5;n++){
  const x=cx+side*(980+n*205),y=h*(.15+(n%3)*.3);
  botanicals+=`<g transform="translate(${x} ${y}) rotate(${side*(20+n*9)})" opacity=".36"><path d="M0 -500 Q-180 -200 0 0 T0 500" fill="none" stroke="#2b6d54" stroke-width="12"/>`;
  for(let l=0;l<9;l++)botanicals+=`<ellipse cx="${l%2?45:-45}" cy="${-360+l*90}" rx="58" ry="24" transform="rotate(${l%2?40:-40} ${l%2?45:-45} ${-360+l*90})" fill="${l%3?'#4c9367':'#72dace'}"/>`;
  botanicals+='</g>';
 }
 const portraits=[-1,1].map((side,i)=>{let x=cx+side*(b/2+g+p/2),y=cy;return `<circle cx="${x}" cy="${y}" r="${p/2+13}" fill="#0a2932" stroke="${i?'#72dace':'#ffbc48'}" stroke-width="9"/><clipPath id="r${i}"><circle cx="${x}" cy="${y}" r="${p/2}"/></clipPath><image href="${uri(i+1)}" x="${x-p/2}" y="${y-p/2}" width="${p}" height="${p}" clip-path="url(#r${i})"/>`}).join('');
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs><radialGradient id="light"><stop stop-color="#245d56"/><stop offset="1" stop-color="#071f2a"/></radialGradient><filter id="shadow" x="-.5" y="-.5" width="2" height="2"><feDropShadow dx="0" dy="20" stdDeviation="22" flood-color="#000" flood-opacity=".3"/></filter></defs><rect width="${w}" height="${h}" fill="url(#light)"/>${botanicals}<path d="M0 ${h*.83} Q${w*.2} ${h*.43} ${w*.45} ${h*.91} Q${w*.75} ${h*.52} ${w} ${h*.78} V${h} H0Z" fill="#133e3d"/><path d="M0 ${h*.96} Q${w*.25} ${h*.69} ${w*.5} ${h*1.06} Q${w*.8} ${h*.64} ${w} ${h*.92} V${h} H0Z" fill="#0a2932"/><path d="M${cx-b/2-g-p} ${cy} H${cx+b/2+g+p}" fill="none" stroke="#72dace" stroke-opacity=".24" stroke-width="4" stroke-dasharray="12 20"/>${portraits}<rect x="${bx-9}" y="${by-9}" width="${b+18}" height="${b+18}" rx="25" fill="#071f2a" stroke="#ffbc48" stroke-width="3" filter="url(#shadow)"/><svg x="${bx}" y="${by}" width="${b}" height="${b}" viewBox="904 240 1280 1280"><image href="${uri(0)}" width="2560" height="1600"/></svg></svg>`;
 const png=await sharp(Buffer.from(svg)).flatten({background:'#071f2a'}).removeAlpha().png().toBuffer();
 await fs.writeFile(path.join(out,spec.name+'.svg'),svg);await fs.writeFile(path.join(out,spec.name+'.png'),png);
 await sharp(png).resize({width:1200}).png().toFile(path.join(out,spec.name+'-preview.png'));
 const meta=await sharp(png).metadata();if(meta.width!==w||meta.height!==h||meta.hasAlpha)throw Error('Invalid export');
 manifest.assets.push({file:spec.name+'.png',width:w,height:h,artSafeArea:spec.safe,criticalArtBounds:[bx-g-p-14,by-9,b+2*g+2*p+28,b+18],sha256:hash(png),hasAlpha:meta.hasAlpha});
 console.log(spec.name,w,h);
}
await fs.writeFile(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
