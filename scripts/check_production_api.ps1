param([string]$DefineFile = 'env/app.production.json', [int]$TimeoutSec = 30)
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $DefineFile -Raw | ConvertFrom-Json
$base = $null
if (-not [Uri]::TryCreate($config.PLAN_BACKEND_BASE_URL, [UriKind]::Absolute, [ref]$base) -or $base.Scheme -ne 'https') {
  throw 'Configure the deployed production API HTTPS origin first.'
}
$healthUri = [Uri]::new($base, '/v1/health')
$health = Invoke-RestMethod -Uri $healthUri -TimeoutSec $TimeoutSec
if ($health.status -ne 'ok' -or $health.productionMode -ne $true) {
  throw 'Production API health failed or production mode is disabled.'
}
if ($health.storage -notin @('postgres', 'firestore')) { throw 'Production API must use persistent storage.' }
if ($health.playBillingConfigured -ne $true) {
  throw 'Google Play purchase verification is not configured on the production API.'
}
foreach ($path in @('/privacy', '/delete-account')) {
  $response = Invoke-WebRequest -Uri ([Uri]::new($base, $path)) -UseBasicParsing -TimeoutSec $TimeoutSec
  if ($response.StatusCode -ne 200 -or $response.Content -notmatch 'DevIA' -or $response.Content -notmatch 'francisco.dsantos.viana@gmail.com') {
    throw "Public legal page unavailable or incorrect: $path"
  }
}
Write-Host 'Production API, Play validation and public legal pages passed.'
