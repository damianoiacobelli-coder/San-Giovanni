import {createRequire} from 'node:module';
import {json,requireSameOrigin,getAdminClient,requireStaff,readJson,safeSubscription} from '../lib/push-common.mjs';
const require=createRequire(import.meta.url);
const webpush=require('web-push');
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export default async request=>{
  if(request.method!=='POST')return json({error:'Metodo non consentito'},405);
  if(!requireSameOrigin(request))return json({error:'Origine non autorizzata'},403);
  try {
    const db=getAdminClient();
    const user=await requireStaff(db,request);
    if(!user)return json({error:'Accesso amministratore necessario'},403);
    const {noticeId}=await readJson(request);
    if(typeof noticeId!=='string'||!uuid.test(noticeId))return json({error:'ID avviso non valido'},400);
    const {data:notice,error:noticeErr}=await db.from('notices').select('id,title,body,published').eq('id',noticeId).maybeSingle();
    if(noticeErr)throw noticeErr;
    if(!notice||!notice.published)return json({error:'Avviso inesistente o non pubblicato'},400);
    const pub=process.env.VAPID_PUBLIC_KEY, priv=process.env.VAPID_PRIVATE_KEY;
    if(!pub||!priv)throw new Error('Chiavi VAPID assenti');
    const {data:subscriptions,error:subscriptionsErr}=await db.from('push_subscriptions').select('endpoint,p256dh,auth').limit(2000);
    if(subscriptionsErr)throw subscriptionsErr;
    if(!subscriptions?.length)return json({ok:true,sent:0,failed:0,reason:'Nessun dispositivo ancora iscritto'});
    // Per evitare invii doppi, il database accetta un solo dispatch per avviso.
    const {error:dispatchErr}=await db.from('push_dispatches').insert({notice_id:noticeId});
    if(dispatchErr){
      if(dispatchErr.code==='23505')return json({ok:true,alreadySent:true,sent:0,failed:0});
      throw dispatchErr;
    }
    webpush.setVapidDetails(process.env.VAPID_SUBJECT || 'https://sangiovanni.netlify.app',pub,priv);
    const payload=JSON.stringify({title:'San Giovanni · '+String(notice.title).slice(0,85),body:String(notice.body||'').slice(0,155),url:'/index.html#avvisi',tag:'notice-'+noticeId});
    let sent=0,failed=0;
    const invalid=[];
    for(let i=0;i<subscriptions.length;i+=25){
      const batch=subscriptions.slice(i,i+25);
      await Promise.all(batch.map(async row=>{
        try{
          const sub=safeSubscription({endpoint:row.endpoint,keys:{p256dh:row.p256dh,auth:row.auth}});
          await webpush.sendNotification({endpoint:sub.endpoint,keys:{p256dh:sub.p256dh,auth:sub.auth}},payload,{TTL:86400,urgency:'normal'});
          sent++;
        }catch(e){failed++;if(e.statusCode===404||e.statusCode===410)invalid.push(row.endpoint);console.error('Push delivery error:',e?.statusCode||'invalid subscription');}
      }));
    }
    await db.from('push_dispatches').update({success_count:sent,failure_count:failed}).eq('notice_id',noticeId);
    if(invalid.length)await db.from('push_subscriptions').delete().in('endpoint',invalid);
    return json({ok:true,sent,failed,limited:subscriptions.length>=2000});
  }catch(e){console.error('push-send:',e?.message||String(e));return json({error:'Impossibile inviare le notifiche. Controlla configurazione e log Netlify.'},500)}
};
