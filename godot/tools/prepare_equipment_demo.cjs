// Mechanical packing only: alpha-aware resampling, measured sockets,
// per-sheet constant scale, foot translation, and extraction of hand occlusion.
const fs = require('node:fs');
const path = require('node:path');
const { PNG } = require('C:/Users/rust1/.workbuddy/binaries/node/workspace/node_modules/pngjs');
const root = path.resolve(__dirname, '..');
const source = path.join(root, 'art_direction/candidates/equipment_demo_20261022/raw');
const refined = path.join(root, 'art_direction/candidates/equipment_demo_20261022/raw_refined');
const out = path.join(root, 'assets/equipment_demo');
// Keep the sprite close to one screen pixel per authored pixel at the v17 camera.
// The larger transparent canvas allows the raised sword to stay inside the pose.
const CW=640, CH=400, FOOT=[180,350], BODY_HEIGHT=230;
const annotations={
 base_idle:[[283,349],[860,349],[284,938],[860,938]],
 iron_idle:[[283,349],[860,349],[284,938],[860,938]],
 robe_idle:[[283,349],[860,349],[284,938],[860,938]],
 base_thrust:[[151,294],[616,240],[1124,238],[1708,226],[408,639],[835,650],[1097,653],[1508,705]],
 iron_thrust:[[151,294],[616,240],[1124,238],[1708,226],[408,639],[835,650],[1097,653],[1508,705]],
 robe_thrust:[[153,271],[618,215],[1130,219],[1722,198],[431,596],[863,609],[1112,613],[1515,671]],
 base_guard:[[200,289],[786,187],[1378,165],[354,692],[791,698],[1243,776]],
 iron_guard:[[190,270],[774,167],[1378,150],[348,664],[785,671],[1238,752]],
 robe_guard:[[192,289],[784,184],[1374,160],[354,695],[792,697],[1235,776]],
};
// The gourd hangs at the rear hip, below the held sword's path.
const waistFractions={idle:[.24,.56],thrust:[.23,.57],guard:[.23,.58]};
function read(name){const directory=['prop_wendao','prop_broken'].includes(name)?refined:source;return PNG.sync.read(fs.readFileSync(path.join(directory,name+'.png')));}
function write(file,png){const full=path.join(out,file);fs.mkdirSync(path.dirname(full),{recursive:true});fs.writeFileSync(full,PNG.sync.write(png));return 'res://assets/equipment_demo/'+file;}
function sample(p, x, y, dst, at){
 const x0=Math.floor(x), y0=Math.floor(y), fx=x-x0, fy=y-y0;
 let alpha=0, red=0, green=0, blue=0;
 for(let dy=0;dy<=1;dy++)for(let dx=0;dx<=1;dx++){
  const px=x0+dx, py=y0+dy;
  if(px<0||py<0||px>=p.width||py>=p.height)continue;
  const weight=(dx?fx:1-fx)*(dy?fy:1-fy);
  const source=(py*p.width+px)*4, a=p.data[source+3]*weight;
  alpha+=a;red+=p.data[source]*a;green+=p.data[source+1]*a;blue+=p.data[source+2]*a;
 }
 if(alpha<16)return;
 dst[at]=Math.round(red/alpha);dst[at+1]=Math.round(green/alpha);
 dst[at+2]=Math.round(blue/alpha);dst[at+3]=Math.round(alpha);
}
function components(p){
 const n=p.width*p.height,labels=new Int32Array(n),queue=new Int32Array(n),parts=[];
 for(let at=0;at<n;at++){
  if(labels[at]||p.data[at*4+3]<128)continue;
  const id=parts.length+1;let head=0,tail=1,minX=p.width,minY=p.height,maxX=0,maxY=0;
  labels[at]=id;queue[0]=at;
  while(head<tail){const q=queue[head++],x=q%p.width,y=Math.floor(q/p.width);minX=Math.min(minX,x);maxX=Math.max(maxX,x);minY=Math.min(minY,y);maxY=Math.max(maxY,y);
   for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const nx=x+dx,ny=y+dy;if((!dx&&!dy)||nx<0||ny<0||nx>=p.width||ny>=p.height)continue;const k=ny*p.width+nx;if(!labels[k]&&p.data[k*4+3]>=128){labels[k]=id;queue[tail++]=k;}}
  }
  parts.push({id,count:tail,minX,minY,maxX,maxY});
 }
 return {labels,parts};
}
const manifest={version:2,canvas:[CW,CH],foot:FOOT,pixelSize:.012,outfits:{},props:{},clips:{idle:{durations:[350,300,350,300]},thrust:{durations:[100,110,80,70,110,70,110,150]},guard:{durations:[100,100,140,150,100,140]}},provenance:{generator:'built-in image_gen',raw:'res://art_direction/candidates/equipment_demo_20261022/raw',refinedSwords:'res://art_direction/candidates/equipment_demo_20261022/raw_refined',prompts:'res://art_direction/candidates/equipment_demo_20261022/prompts',processing:'alpha-aware resampling; constant scale per action sheet; translation to rear foot; original hand pixel mask; no invented poses',carrier:'authored full-body outfit variants + independent weapon/accessory/artifact layers'},packing:[]};
for(const [key,grips]of Object.entries(annotations)){
 const [outfit,action]=key.split('_'), p=read(key), {parts,labels}=components(p);
 const figures=parts.filter(x=>x.count>5000).sort((a,b)=>Math.floor((a.minY+a.maxY)/p.height)-Math.floor((b.minY+b.maxY)/p.height)||a.minX-b.minX);
 if(figures.length!==grips.length)throw Error(key+': expected '+grips.length+' figures, got '+figures.length);
 const scale=BODY_HEIGHT/(figures[0].maxY-figures[0].minY+1);
 const id=outfit==='iron'?'玄铁甲':outfit==='robe'?'灵纹法袍':'base';
 manifest.outfits[id]??={};manifest.outfits[id][action]=[];
 figures.forEach((f,i)=>{
  let footX=p.width;
  for(let y=Math.max(f.minY,f.maxY-Math.ceil((f.maxY-f.minY)*.045));y<=f.maxY;y++)for(let x=f.minX;x<=f.maxX;x++)if(labels[y*p.width+x]===f.id)footX=Math.min(footX,x);
  footX+=(f.maxY-f.minY)*.025;
  const transform=(xy)=>[Math.round(FOOT[0]+(xy[0]-footX)*scale),Math.round(FOOT[1]+(xy[1]-f.maxY)*scale)];
  const frame=new PNG({width:CW,height:CH});
  for(let y=0;y<CH;y++)for(let x=0;x<CW;x++){
   const sx=(x-FOOT[0])/scale+footX,sy=(y-FOOT[1])/scale+f.maxY;
   if(sx<f.minX-3||sx>f.maxX+3||sy<f.minY-3||sy>f.maxY+3||sx<0||sy<0||sx>=p.width||sy>=p.height)continue;
   const di=(y*CW+x)*4;
   sample(p,sx,sy,frame.data,di);
  }
  const grip=transform(grips[i]),hand=new PNG({width:CW,height:CH}),skin=[];
  for(let y=Math.max(0,grip[1]-11);y<Math.min(CH,grip[1]+12);y++)for(let x=Math.max(0,grip[0]-10);x<Math.min(CW,grip[0]+11);x++){
   const k=(y*CW+x)*4,[r,g,b,a]=frame.data.subarray(k,k+4);
   if(a&&r>90&&r>g*1.15&&g>b*1.13)skin.push([x,y]);
  }
  if(!skin.length)throw Error(key+' frame'+i+' hand marker outside skin '+grip);
  for(const [x,y]of skin)for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=CW||ny>=CH)continue;const k=(ny*CW+nx)*4;frame.data.copy(hand.data,k,k,k+4);}
  const file=write(outfit+'/'+action+'/'+i+'.png',frame),handFile=write(outfit+'/'+action+'/'+i+'_hand.png',hand);
  const w=f.maxX-f.minX,h=f.maxY-f.minY,frac=waistFractions[action];
  const waist=transform([f.minX+w*frac[0],f.minY+h*frac[1]]);
  const back=transform([f.minX+w*.29,f.minY+h*.35]);
  const angle=action==='guard'?[-4,-28,-57,-57,-28,-4][i]:action==='idle'?-4:[-4,-2,-1,0,0,0,-2,-4][i];
  const gourdAngle=action==='thrust'?[0,5,12,18,24,12,-8,0][i]:action==='guard'?[0,3,7,12,5,0][i]:[0,1,2,1][i];
  manifest.outfits[id][action].push({file,handFile,grip,waist,back,angle,gourdAngle,backAngle:action==='thrust'?[-12,-15,-18,-24,-24,-20,-15,-12][i]:-12});
  manifest.packing.push({sheet:key,index:i,scale,sourceBounds:f,sourceFoot:[footX,f.maxY],sourceGrip:grips[i],outputGrip:grip});
 });
}
for(const [name,id,target,gripFraction]of [
 ['prop_wendao','问道剑',190,.16],['prop_broken','brokenSword',118,.16],
 ['prop_gourd','灵泉葫芦',43,null],['prop_swordbox','青云剑匣',115,null]]){
 const p=read(name),f=components(p).parts.sort((a,b)=>b.count-a.count)[0];
 const sw=f.maxX-f.minX+1,sh=f.maxY-f.minY+1,s=target/(gripFraction?sw:sh),w=Math.ceil(sw*s)+4,h=Math.ceil(sh*s)+4,tex=new PNG({width:w,height:h});
 for(let y=2;y<h-2;y++)for(let x=2;x<w-2;x++){
  const sx=(x-2)/s+f.minX,sy=(y-2)/s+f.minY,di=(y*w+x)*4;
  sample(p,sx,sy,tex.data,di);
 }
 const entry={file:write('props/'+name+'.png',tex)};
 if(gripFraction){entry.grip=[Math.round(sw*gripFraction*s)+2,Math.round(sh*.5*s)+2];entry.tip=[w-3,Math.round(h/2)];}
 else entry.anchor=name==='prop_gourd'?[Math.round(w*.46),5]:[Math.round(w*.5),Math.round(h*.58)];
 manifest.props[id]=entry;
}
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2));
console.log(JSON.stringify({outfits:Object.keys(manifest.outfits),bodyFrames:manifest.packing.length,props:Object.keys(manifest.props),canvas:manifest.canvas,manifest:path.join(out,'manifest.json')}));
