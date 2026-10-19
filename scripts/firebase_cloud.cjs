// Uses the Firebase CLI's signed-in account in memory; never prints tokens.
const fs = require('node:fs');
const path = require('node:path');
const cliLib = path.join(process.env.APPDATA, 'npm/node_modules/firebase-tools/lib');
const auth = require(path.join(cliLib, 'auth.js'));
const { requireAuth } = require(path.join(cliLib, 'requireAuth.js'));
const { Client } = require(path.join(cliLib, 'apiv2.js'));

async function main() {
  const project = JSON.parse(fs.readFileSync('.firebaserc', 'utf8')).projects.default;
  const account = auth.getProjectDefaultAccount(process.cwd());
  if (!account) throw new Error('Run firebase login first.');
  await requireAuth({ ...account, project, nonInteractive: true });
  const billing = new Client({ urlPrefix: 'https://cloudbilling.googleapis.com', apiVersion: 'v1' });
  const result = await billing.get(`/projects/${project}/billingInfo`);
  console.log(JSON.stringify({ projectId: project, billingEnabled: result.body.billingEnabled === true }));
}

main().catch(error => {
  console.error(error.message || 'Firebase cloud operation failed.');
  process.exitCode = 1;
});
