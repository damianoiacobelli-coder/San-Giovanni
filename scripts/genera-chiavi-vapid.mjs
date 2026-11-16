// Eseguire localmente UNA VOLTA: npm run gen:vapid
// Non copiare mai la chiave privata nel sito web, GitHub o in una chat.
import { generateKeyPairSync } from 'node:crypto';
const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
const priv = privateKey.export({format:'jwk'});
const pub = publicKey.export({format:'jwk'});
const decode=s=>Buffer.from(s,'base64url');
const pubRaw=Buffer.concat([Buffer.from([4]),decode(pub.x),decode(pub.y)]).toString('base64url');
console.log('\nVAPID_PUBLIC_KEY=' + pubRaw);
console.log('VAPID_PRIVATE_KEY=' + priv.d);
console.log('\nConserva la chiave privata esclusivamente nelle Environment variables di Netlify.');
console.log('Non salvarla in config.js, netlify.toml o nel repository.\n');
