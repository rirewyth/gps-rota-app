import http from 'http';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = 5175;
const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'service-account.json');

let cachedToken = null;
let cachedExpiry = 0;

function base64Url(input) {
  return Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

async function getAccessToken(sa) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && now < cachedExpiry - 60) {
    return cachedToken;
  }

  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64Url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    })
  );

  const unsigned = `${header}.${claim}`;
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(unsigned);
  const signature = sign
    .sign(sa.private_key, 'base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const jwt = `${unsigned}.${signature}`;

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!res.ok || !data.access_token) {
    throw new Error(data.error_description || data.error || 'OAuth2 token alinamadi');
  }

  cachedToken = data.access_token;
  cachedExpiry = now + (data.expires_in || 3600);
  return cachedToken;
}

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ ok: true, hasServiceAccount: fs.existsSync(SERVICE_ACCOUNT_PATH) }));
    return;
  }

  if (req.method === 'POST' && req.url === '/send-push') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', async () => {
      try {
        if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(
            JSON.stringify({
              ok: false,
              error: 'service-account.json bulunamadi (ROTA+ NEXUS klasorune ekleyin).',
            })
          );
          return;
        }

        const sa = JSON.parse(fs.readFileSync(SERVICE_ACCOUNT_PATH, 'utf8'));
        const { tokens = [], title = '📡 ROTA+ NEXUS KOMUTA', body: msgBody = '' } = JSON.parse(body || '{}');
        const uniqueTokens = [...new Set(tokens.filter(Boolean))];

        if (uniqueTokens.length === 0) {
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ ok: true, sent: 0, note: 'Token yok' }));
          return;
        }

        const accessToken = await getAccessToken(sa);
        const fcmUrl = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

        let sent = 0;
        let failed = 0;

        for (const token of uniqueTokens) {
          const r = await fetch(fcmUrl, {
            method: 'POST',
            headers: {
              Authorization: `Bearer ${accessToken}`,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              message: {
                token,
                notification: { title, body: msgBody },
                data: {
                  click_action: 'FLUTTER_NOTIFICATION_CLICK',
                  type: 'nexus_dispatch',
                },
                android: {
                  priority: 'HIGH',
                  notification: {
                    channel_id: 'rota_plus_fcm_channel',
                    sound: 'default',
                  },
                },
                apns: {
                  payload: {
                    aps: { sound: 'default' },
                  },
                },
              },
            }),
          });
          if (r.ok) sent++;
          else failed++;
        }

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: true, sent, failed }));
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ ok: false, error: err.message }));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end('Not Found');
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[ROTA+ NEXUS PUSH RELAY] http://127.0.0.1:${PORT} aktif.`);
  if (!fs.existsSync(SERVICE_ACCOUNT_PATH)) {
    console.log('[UYARI] Kapali telefonlara FCM push icin service-account.json dosyasini bu klasore koyun.');
  }
});
