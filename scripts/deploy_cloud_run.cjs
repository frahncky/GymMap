// Implanta a API do GymMap no Cloud Run (dados no Firestore) e publica o
// Firebase Hosting na frente dela. Usa a conta do `firebase login` em memória
// e nunca imprime tokens nem segredos. Os segredos vêm de
// backend/.env.production (fora do Git) e vão para o Secret Manager.
//
//   node scripts/deploy_cloud_run.cjs
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, execSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const cliLib = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const auth = require(path.join(cliLib, 'auth.js'));
const { requireAuth } = require(path.join(cliLib, 'requireAuth.js'));

const project = JSON.parse(fs.readFileSync(path.join(root, '.firebaserc'), 'utf8')).projects.default;
const region = 'southamerica-east1';
const service = 'gymmap-api';
const origin = `https://${project}.web.app`;
const repo = 'gymmap';

const services = [
  'run.googleapis.com',
  'cloudbuild.googleapis.com',
  'artifactregistry.googleapis.com',
  'firestore.googleapis.com',
  'secretmanager.googleapis.com',
  'storage.googleapis.com',
  'androidpublisher.googleapis.com',
  'firebasehosting.googleapis.com',
  'firebaserules.googleapis.com',
];

// Vão para o Secret Manager; o resto vai como variável comum.
const secretKeys = [
  'JWT_HS256_SECRET',
  'WEBHOOK_SIGNING_SECRET',
  'ADMIN_API_TOKEN',
  'PIX_PROVIDER_API_KEY',
  'PIX_MP_DEFAULT_PAYER_EMAIL',
  'AUTH_USERS_JSON',
];
const plainKeys = [
  'PIX_PROVIDER_MODE',
  'PIX_PROVIDER_VENDOR',
  'PIX_PROVIDER_BASE_URL',
  'PIX_PROVIDER_CHARGE_PATH',
  'PIX_PROVIDER_STATUS_PATH_TEMPLATE',
  'PIX_PROVIDER_TIMEOUT_SEC',
  'PLAY_PACKAGE_NAME',
  'PLAY_PRODUCT_ID_SMART',
  'PLAY_PRODUCT_ID_PRO',
  'PLAY_PRODUCT_ID_ELITE',
  'JWT_ISSUER',
  'JWT_ACCESS_TTL_SEC',
  'WEBHOOK_SIGNATURE_TOLERANCE_SEC',
  'RATE_LIMIT_REQUESTS_PER_MIN',
  'RATE_LIMIT_LOGIN_ATTEMPTS_PER_MIN',
  'RATE_LIMIT_BILLING_ATTEMPTS_PER_MIN',
  'CHARGE_RETENTION_DAYS',
  'WEBHOOK_RETENTION_DAYS',
  'CROWD_REPORT_RETENTION_DAYS',
  'REQUEST_LOG_DISABLED',
];
// Valores próprios desta hospedagem (substituem os do arquivo).
const fixedEnv = {
  HOST: '0.0.0.0',
  BACKEND_PRODUCTION_MODE: 'true',
  FIRESTORE_PROJECT_ID: project,
  CORS_ALLOW_ORIGIN: origin,
  PIX_MP_NOTIFICATION_URL: `${origin}/v1/webhooks/pix`,
  PLAY_BILLING_ALLOW_UNVERIFIED: 'false',
  // Compras validadas com a conta de serviço do próprio Cloud Run.
  PLAY_USE_APPLICATION_DEFAULT: 'true',
  // O Hosting e o Cloud Run informam o IP de quem chamou.
  TRUST_PROXY_HEADERS: 'true',
};

function readEnvFile() {
  const text = fs.readFileSync(path.join(root, 'backend/.env.production'), 'utf8').replace(/^﻿/, '');
  const env = {};
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^([A-Z0-9_]+)=(.*)$/);
    if (match) env[match[1]] = match[2].trim();
  }
  return env;
}

let accessToken;
async function api(method, url, body, { allow = [], raw, contentType } = {}) {
  const res = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': contentType || 'application/json',
    },
    body: raw ?? (body === undefined ? undefined : JSON.stringify(body)),
  });
  const text = await res.text();
  if (!res.ok && !allow.includes(res.status)) {
    // Mensagem do Google sem cabeçalhos nem corpo enviado.
    let message = text.slice(0, 600);
    try { message = JSON.parse(text).error.message; } catch (_) {}
    throw new Error(`${method} ${url.split('?')[0]} -> ${res.status}: ${message}`);
  }
  return { status: res.status, body: text ? JSON.parse(text) : {} };
}

async function waitOperation(base, op, label) {
  let current = op;
  for (let i = 0; !current.done; i++) {
    if (i > 240) throw new Error(`${label}: tempo esgotado`);
    await new Promise(r => setTimeout(r, 5000));
    current = (await api('GET', `${base}/${current.name}`)).body;
  }
  if (current.error) throw new Error(`${label}: ${current.error.message}`);
  return current;
}

function step(text) {
  console.log(`\n> ${text}`);
}

async function main() {
  const env = readEnvFile();
  for (const key of secretKeys.filter(k => k !== 'AUTH_USERS_JSON')) {
    if (!env[key]) throw new Error(`Falta ${key} em backend/.env.production`);
  }

  const account = auth.getProjectDefaultAccount(root);
  if (!account) throw new Error('Rode firebase login primeiro.');
  await requireAuth({ ...account, project, nonInteractive: true });
  accessToken = (await auth.getAccessToken(account.tokens.refresh_token, [])).access_token;

  const info = (await api('GET', `https://cloudresourcemanager.googleapis.com/v1/projects/${project}`)).body;
  const runtimeAccount = `${info.projectNumber}-compute@developer.gserviceaccount.com`;

  step('Ativando APIs');
  const enable = await api('POST', `https://serviceusage.googleapis.com/v1/projects/${project}/services:batchEnable`, { serviceIds: services });
  await waitOperation('https://serviceusage.googleapis.com/v1', enable.body, 'ativar APIs');

  step('Banco Firestore');
  const fsBase = 'https://firestore.googleapis.com/v1';
  const db = await api('GET', `${fsBase}/projects/${project}/databases/(default)`, undefined, { allow: [404] });
  if (db.status === 404) {
    const created = await api('POST', `${fsBase}/projects/${project}/databases?databaseId=(default)`, {
      locationId: region,
      type: 'FIRESTORE_NATIVE',
    });
    await waitOperation(fsBase, created.body, 'criar Firestore');
    console.log(`  criado em ${region}`);
  } else {
    console.log(`  já existe (${db.body.locationId})`);
  }

  step('Repositório de imagens');
  const arBase = 'https://artifactregistry.googleapis.com/v1';
  const repoRes = await api('POST', `${arBase}/projects/${project}/locations/${region}/repositories?repositoryId=${repo}`, { format: 'DOCKER' }, { allow: [409] });
  if (repoRes.status !== 409) await waitOperation(arBase, repoRes.body, 'criar repositório');

  step('Enviando o código (somente arquivos do Git)');
  const commit = execFileSync('git', ['rev-parse', '--short', 'HEAD'], { cwd: root }).toString().trim();
  const archive = execFileSync('git', ['archive', '--format=tar.gz', 'HEAD'], { cwd: root, maxBuffer: 512 * 1024 * 1024 });
  const bucket = `${project}_cloudbuild`;
  await api('POST', `https://storage.googleapis.com/storage/v1/b?project=${project}`, { name: bucket, location: region }, { allow: [409] });
  const object = `source/gymmap-${commit}-${Date.now()}.tgz`;
  await api('POST', `https://storage.googleapis.com/upload/storage/v1/b/${bucket}/o?uploadType=media&name=${encodeURIComponent(object)}`, undefined, {
    raw: archive,
    contentType: 'application/gzip',
  });
  console.log(`  ${(archive.length / 1024 / 1024).toFixed(1)} MB, commit ${commit}`);

  step('Compilando a imagem no Cloud Build');
  const image = `${region}-docker.pkg.dev/${project}/${repo}/${service}:${commit}`;
  const buildRequest = {
    source: { storageSource: { bucket, object } },
    steps: [{ name: 'gcr.io/cloud-builders/docker', args: ['build', '-f', 'backend/Dockerfile', '-t', image, '.'] }],
    images: [image],
    serviceAccount: `projects/${project}/serviceAccounts/${runtimeAccount}`,
    options: { logging: 'CLOUD_LOGGING_ONLY' },
    timeout: '1800s',
  };
  // Logo após ativar a API, o Cloud Build recusa (403) por alguns minutos.
  let build;
  for (let attempt = 1; ; attempt++) {
    build = await api('POST', `https://cloudbuild.googleapis.com/v1/projects/${project}/builds`, buildRequest, { allow: [403] });
    if (build.status !== 403) break;
    if (attempt === 12) throw new Error('Cloud Build continua sem permissão (403). Confira se a conta logada é Proprietária do projeto.');
    console.log('  Cloud Build ainda ativando, nova tentativa em 30 s...');
    await new Promise(r => setTimeout(r, 30000));
  }
  await waitOperation('https://cloudbuild.googleapis.com/v1', build.body, 'compilar imagem');
  console.log(`  ${image}`);

  step('Segredos no Secret Manager');
  const smBase = `https://secretmanager.googleapis.com/v1/projects/${project}/secrets`;
  const secretEnv = [];
  for (const key of secretKeys) {
    const value = key === 'AUTH_USERS_JSON' ? (env[key] || '{}') : env[key];
    const id = `gymmap-${key.toLowerCase().replace(/_/g, '-')}`;
    await api('POST', `${smBase}?secretId=${id}`, { replication: { automatic: {} } }, { allow: [409] });
    await api('POST', `${smBase}/${id}:addVersion`, { payload: { data: Buffer.from(value, 'utf8').toString('base64') } });
    await api('POST', `${smBase}/${id}:setIamPolicy`, {
      policy: { bindings: [{ role: 'roles/secretmanager.secretAccessor', members: [`serviceAccount:${runtimeAccount}`] }] },
    });
    secretEnv.push({ name: key, valueSource: { secretKeyRef: { secret: id, version: 'latest' } } });
    console.log(`  ${key}`);
  }

  step('Serviço no Cloud Run');
  const plainEnv = { ...Object.fromEntries(plainKeys.filter(k => env[k]).map(k => [k, env[k]])), ...fixedEnv };
  const runBase = 'https://run.googleapis.com/v2';
  const parent = `projects/${project}/locations/${region}`;
  const spec = {
    ingress: 'INGRESS_TRAFFIC_ALL',
    template: {
      serviceAccount: runtimeAccount,
      // Uma instância: o estado fica em memória e é conferido no Firestore.
      scaling: { minInstanceCount: 0, maxInstanceCount: 1 },
      containers: [{
        image,
        ports: [{ containerPort: 8080 }],
        resources: { limits: { cpu: '1', memory: '512Mi' } },
        env: [...Object.entries(plainEnv).map(([name, value]) => ({ name, value })), ...secretEnv],
        startupProbe: { httpGet: { path: '/v1/health' }, periodSeconds: 5, failureThreshold: 24 },
      }],
    },
  };
  const existing = await api('GET', `${runBase}/${parent}/services/${service}`, undefined, { allow: [404] });
  const runOp = existing.status === 404
    ? await api('POST', `${runBase}/${parent}/services?serviceId=${service}`, spec)
    : await api('PATCH', `${runBase}/${parent}/services/${service}`, spec);
  const done = await waitOperation(runBase, runOp.body, 'implantar Cloud Run');
  await api('POST', `${runBase}/${parent}/services/${service}:setIamPolicy`, {
    policy: { bindings: [{ role: 'roles/run.invoker', members: ['allUsers'] }] },
  });
  console.log(`  ${done.response?.uri || service}`);

  step('Firebase Hosting e regras do Firestore');
  execSync(`firebase deploy --only hosting,firestore --project ${project} --non-interactive`, {
    cwd: root,
    stdio: 'inherit',
  });

  console.log(`\nAPI publicada em ${origin}`);
  console.log(`Para validar compras, adicione ${runtimeAccount} no Play Console (Usuários e permissões).`);
}

main().catch(error => {
  console.error(`\nFalhou: ${error.message}`);
  process.exitCode = 1;
});
