import {json} from '../lib/push-common.mjs';
export default async request=>{
  if(request.method!=='GET')return json({error:'Metodo non consentito'},405);
  const publicKey=process.env.VAPID_PUBLIC_KEY;
  if(!publicKey)return json({error:'Notifiche non ancora configurate sul server'},503);
  return json({publicKey});
};
