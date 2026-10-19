// Cria a conta que a revisão do Google Play usa e libera o plano Elite
// (o máximo) por 365 dias, sem cobrança. O token de admin vem de
// backend/.env.production e nunca é impresso.
//
//   node scripts/grant_review_access.cjs [usuario]
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const root = path.resolve(__dirname, '..');
const project = JSON.parse(fs.readFileSync(path.join(root, '.firebaserc'), 'utf8')).projects.default;
const base = `https://${project}.web.app`;
const username = process.argv[2] || 'revisao_play';
const planKey = 'elite';
const days = 365;

function adminToken() {
  const text = fs.readFileSync(path.join(root, 'backend/.env.production'), 'utf8').replace(/^﻿/, '');
  const match = text.match(/^ADMIN_API_TOKEN=(.*)$/m);
  if (!match || !match[1].trim()) throw new Error('Falta ADMIN_API_TOKEN em backend/.env.production');
  return match[1].trim();
}

async function post(pathname, body, token) {
  const res = await fetch(`${base}${pathname}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`${pathname} -> ${res.status} ${data.error || ''}`.trim());
  return data;
}

async function main() {
  // Senha forte e legível para digitar no Play Console.
  const password = crypto.randomBytes(12).toString('base64url');
  const created = await post('/v1/auth/register', { username, password });
  await post('/v1/admin/subscriptions/grant', { userId: created.userId, planKey, days }, adminToken());
  console.log('Conta de revisão criada com o plano Elite por 365 dias.');
  console.log(`Usuário: ${username}`);
  console.log(`Senha:   ${password}`);
}

main().catch(error => {
  console.error(`Falhou: ${error.message}`);
  process.exitCode = 1;
});
