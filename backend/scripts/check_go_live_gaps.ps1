param(
  [string]$BackendEnvFile = "backend/.env.production",
  [string]$AppDefineFile = "env/app.production.json"
)

$ErrorActionPreference = "Stop"

function Read-EnvFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Env file not found: $Path"
  }
  $map = @{}
  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { return }
    if ($line.StartsWith("#")) { return }
    $idx = $line.IndexOf("=")
    if ($idx -lt 1) { return }
    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    $map[$key] = $value
  }
  return $map
}

function LooksLikePlaceholder {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
  if ($Value.Contains("<") -or $Value.Contains(">")) { return $true }
  $v = $Value.ToLowerInvariant()
  if ($v.Contains("seudominio")) { return $true }
  if ($v.Contains("seu_dominio")) { return $true }
  if ($v.Contains("base64_of_service_account_json")) { return $true }
  if ($v.Contains("strong_")) { return $true }
  return $false
}

$envMap = Read-EnvFile -Path $BackendEnvFile

if (-not (Test-Path $AppDefineFile)) {
  throw "App define file not found: $AppDefineFile"
}
$appRaw = Get-Content $AppDefineFile -Raw -Encoding UTF8
$appJson = $appRaw | ConvertFrom-Json

$gaps = New-Object System.Collections.Generic.List[string]

$requiredBackend = @(
  "DATABASE_URL",
  "JWT_HS256_SECRET",
  "ADMIN_API_TOKEN",
  "PIX_MP_NOTIFICATION_URL",
  "PLAY_PACKAGE_NAME",
  "PLAY_SERVICE_ACCOUNT_JSON_BASE64",
  "PLAY_PRODUCT_ID_SMART",
  "PLAY_PRODUCT_ID_PRO",
  "PLAY_PRODUCT_ID_ELITE",
  "AUTH_USERS_JSON",
  "CORS_ALLOW_ORIGIN"
)

foreach ($key in $requiredBackend) {
  $value = ""
  if ($envMap.ContainsKey($key)) { $value = "$($envMap[$key])" }
  if (LooksLikePlaceholder -Value $value) {
    $gaps.Add("$key not finalized in $BackendEnvFile")
  }
}

$pixEmail = if ($envMap.ContainsKey("PIX_MP_DEFAULT_PAYER_EMAIL")) { "$($envMap["PIX_MP_DEFAULT_PAYER_EMAIL"])" } else { "" }
if ($pixEmail.Contains("<") -or $pixEmail.Contains(">")) {
  $gaps.Add("PIX_MP_DEFAULT_PAYER_EMAIL contains angle brackets. Remove '<' and '>'.")
}

$backendBaseUrl = "$($appJson.PLAN_BACKEND_BASE_URL)"
if (LooksLikePlaceholder -Value $backendBaseUrl) {
  $gaps.Add("PLAN_BACKEND_BASE_URL not finalized in $AppDefineFile")
}

if ($gaps.Count -eq 0) {
  Write-Host "No go-live gaps detected in local config files." -ForegroundColor Green
  exit 0
}

Write-Host "Go-live gaps detected:" -ForegroundColor Yellow
$gaps | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
exit 2
