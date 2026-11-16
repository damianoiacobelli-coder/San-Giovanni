import {createClient} from '@supabase/supabase-js';

export const json=(payload,status=200)=>new Response(JSON.stringify(payload),{
  status,headers:{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}
});

export function requireSameOrigin(request){
  const origin=request.headers.get('origin');
  let requestOrigin;
  try {requestOrigin=new URL(request.url).origin;} catch {return false;}
  const site=process.env.SITE_ORIGIN || requestOrigin;
  return Boolean(origin && origin===site);
}

export function getAdminClient(){
  const url=process.env.SUPABASE_URL;
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url||!serviceKey)throw new Error('Configurazione del server incompleta: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY');
  return createClient(url,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
}

const allowedHosts = h => h==='fcm.googleapis.com'
  || h==='fcm-xm.googleapis.com'
  || h==='updates.push.services.mozilla.com'
  || h==='web.push.apple.com'
  || h.endsWith('.push.apple.com')
  || h==='notify.windows.com'
  || h.endsWith('.notify.windows.com');

export function safeSubscription(input){
  if(!input || typeof input!=='object')throw new Error('Sottoscrizione mancante');
  const endpoint=String(input.endpoint||'');
  let url;
  try {url=new URL(endpoint);} catch {throw new Error('Endpoint non valido');}
  if(url.protocol!=='https:' || url.username||url.password||url.port||!allowedHosts(url.hostname.toLowerCase())||endpoint.length>2048) throw new Error('Endpoint push non supportato');
  const keys=input.keys||{};
  const p256dh=String(keys.p256dh||'');
  const auth=String(keys.auth||'');
  if(!/^[A-Za-z0-9_-]{80,150}$/.test(p256dh)||!/^[A-Za-z0-9_-]{16,120}$/.test(auth))throw new Error('Chiavi push non valide');
  return {endpoint, p256dh, auth};
}

export async function requireStaff(client,request){
  const authorization=request.headers.get('authorization')||'';
  const match=/^Bearer\s+([\w.\-]+)$/.exec(authorization);
  if(!match)return null;
  const {data,error}=await client.auth.getUser(match[1]);
  if(error||!data?.user)return null;
  const role=await client.from('admin_members').select('role').eq('user_id',data.user.id).maybeSingle();
  if(role.error||!['admin','editor'].includes(role.data?.role))return null;
  return data.user;
}

export const readJson=async request=>{
  const raw=await request.text();
  if(raw.length>12000)throw new Error('Richiesta troppo grande');
  try{return JSON.parse(raw)}catch{throw new Error('JSON non valido')}
};
