import {json,requireSameOrigin,getAdminClient,safeSubscription,readJson} from '../lib/push-common.mjs';
export default async request=>{
  if(request.method!=='POST'&&request.method!=='DELETE')return json({error:'Metodo non consentito'},405);
  if(!requireSameOrigin(request))return json({error:'Origine non autorizzata'},403);
  try{
    const sub=safeSubscription(await readJson(request));
    const db=getAdminClient();
    if(request.method==='POST'){
      const {error}=await db.from('push_subscriptions').upsert({endpoint:sub.endpoint,p256dh:sub.p256dh,auth:sub.auth,updated_at:new Date().toISOString()},{onConflict:'endpoint'});
      if(error)throw error;
      return json({ok:true});
    }
    const {error}=await db.from('push_subscriptions').delete().eq('endpoint',sub.endpoint);
    if(error)throw error;
    return json({ok:true});
  }catch(e){console.error('push-subscribe:',e?.message||String(e));return json({error:e?.message||'Operazione non riuscita'},400)}
};
