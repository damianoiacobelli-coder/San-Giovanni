// San Giovanni v9 – service worker per PWA + notifiche push.
const CACHE='san-giovanni-v13-banner-definitivo';
const FILES=['./','./index.html','./cei-almanacco.html','./config.js','./manifest.webmanifest','./icon.svg','./icon-192.png','./icon-512.png','./banner-definitivo.webp','./banner-mobile-testo.webp','./banner-mobile-comunita.webp'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  for(const key of await caches.keys())if(key!==CACHE&&key.startsWith('san-giovanni'))await caches.delete(key);
  await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
  const u=new URL(event.request.url);
  if(event.request.method!=='GET'||u.origin!==self.location.origin||u.pathname.includes('/.netlify/functions/'))return;
  event.respondWith(fetch(event.request).then(response=>{
    if(response.ok&&['document','script','style','image','manifest'].includes(event.request.destination||'document')){
      const copy=response.clone();caches.open(CACHE).then(cache=>cache.put(event.request,copy)).catch(()=>{});
    }
    return response;
  }).catch(()=>caches.match(event.request)));
});
self.addEventListener('push',event=>{
  let data={};
  try{data=event.data?.json()||{}}catch{data={body:event.data?.text()||''}}
  const title=String(data.title||'San Giovanni Nettuno').slice(0,120);
  const options={body:String(data.body||'Nuovo avviso della parrocchia').slice(0,180),tag:String(data.tag||'san-giovanni'),icon:'/icon-192.png',badge:'/icon-192.png',data:{url:'/index.html#avvisi'}};
  event.waitUntil(self.registration.showNotification(title,options));
});
self.addEventListener('notificationclick',event=>{
  event.notification.close();
  const target=new URL('/index.html#avvisi',self.location.origin).href;
  event.waitUntil((async()=>{
    const windows=await clients.matchAll({type:'window',includeUncontrolled:true});
    for(const w of windows){if(new URL(w.url).origin===self.location.origin){await w.focus();w.navigate(target);return}}
    await clients.openWindow(target);
  })());
});
