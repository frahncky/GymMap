param(
  [string]$EnvFile = "backend/.env.production"
)

$ErrorActionPreference = "Stop"

function Import-EnvFile {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Environment file not found: $Path"
  }

  Get-Content $Path | ForEach-Object {
    $line = $_.Trim()
    if ([string]::IsNullOrWhiteSpace($line)) { return }
    if ($line.StartsWith("#")) { return }
    $idx = $line.IndexOf("=")
    if ($idx -lt 1) { return }
    $key = $line.Substring(0, $idx).Trim()
    $value = $line.Substring($idx + 1).Trim()
    [Environment]::SetEnvironmentVariable($key, $value, "Process")
  }
}

Import-EnvFile -Path $EnvFile

$required = @(
  "BACKEND_PRODUCTION_MODE",
  "DATABASE_URL",
  "JWT_HS256_SECRET",
  "WEBHOOK_SIGNING_SECRET",
  "CORS_ALLOW_ORIGIN",
  "ADMIN_API_TOKEN",
  "PIX_PROVIDER_MODE",
  "PIX_PROVIDER_VENDOR",
  "PIX_PROVIDER_BASE_URL",
  "PIX_PROVIDER_API_KEY"
)

$errors = New-Object System.Collections.Generic.List[string]

foreach ($name in $required) {
  $value = [Environment]::GetEnvironmentVariable($name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    $errors.Add("$name is required.")
  }
}

$productionMode = [Environment]::GetEnvironmentVariable("BACKEND_PRODUCTION_MODE", "Process")
if ($null -eq $productionMode) {
  $productionMode = ""
}
$productionMode = $productionMode.ToLowerInvariant()
if ($productionMode -notin @("1", "true", "yes", "on")) {
  $errors.Add("BACKEND_PRODUCTION_MODE must be true in production env file.")
}

$cors = [Environment]::GetEnvironmentVariable("CORS_ALLOW_ORIGIN", "Process")
if ($cors -eq "*") {
  $errors.Add("CORS_ALLOW_ORIGIN cannot be '*'.")
}

$fallbackPassword = [Environment]::GetEnvironmentVariable("AUTH_DEFAULT_PASSWORD", "Process")
if (-not [string]::IsNullOrWhiteSpace($fallbackPassword)) {
  $errors.Add("AUTH_DEFAULT_PASSWORD must be empty in production.")
}

$adminToken = [Environment]::GetEnvironmentVariable("ADMIN_API_TOKEN", "Process")
if ([string]::IsNullOrWhiteSpace($adminToken) -or $adminToken.Length -lt 24) {
  $errors.Add("ADMIN_API_TOKEN must contain at least 24 characters.")
}

$pixMode = ([Environment]::GetEnvironmentVariable("PIX_PROVIDER_MODE", "Process") + "").ToLowerInvariant().Trim()
if ($pixMode -ne "external") {
  $errors.Add("PIX_PROVIDER_MODE must be 'external' in production.")
}

$pixVendor = ([Environment]::GetEnvironmentVariable("PIX_PROVIDER_VENDOR", "Process") + "").ToLowerInvariant().Trim()
if ($pixVendor -notin @("generic", "mercado_pago", "mercadopago")) {
  $errors.Add("PIX_PROVIDER_VENDOR must be generic or mercado_pago.")
}

$webhookToken = [Environment]::GetEnvironmentVariable("WEBHOOK_TOKEN", "Process")
if (($pixVendor -ne "mercado_pago" -and $pixVendor -ne "mercadopago") -and [string]::IsNullOrWhiteSpace($webhookToken)) {
  $errors.Add("WEBHOOK_TOKEN is required when PIX_PROVIDER_VENDOR is not mercado_pago.")
}

$pixPayerEmail = [Environment]::GetEnvironmentVariable("PIX_MP_DEFAULT_PAYER_EMAIL", "Process")
if (($pixVendor -eq "mercado_pago" -or $pixVendor -eq "mercadopago") -and [string]::IsNullOrWhiteSpace($pixPayerEmail)) {
  $errors.Add("PIX_MP_DEFAULT_PAYER_EMAIL is required for Mercado Pago.")
}

function Validate-IntRange {
  param(
    [string]$Name,
    [int]$Min,
    [int]$Max
  )
  $raw = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($raw)) { return }
  $value = 0
  if (-not [int]::TryParse($raw, [ref]$value)) {
    $errors.Add("$Name must be an integer.")
    return
  }
  if ($value -lt $Min -or $value -gt $Max) {
    $errors.Add("$Name must be between $Min and $Max.")
  }
}

Validate-IntRange -Name "RATE_LIMIT_REQUESTS_PER_MIN" -Min 30 -Max 6000
Validate-IntRange -Name "RATE_LIMIT_LOGIN_ATTEMPTS_PER_MIN" -Min 3 -Max 600
Validate-IntRange -Name "RATE_LIMIT_BILLING_ATTEMPTS_PER_MIN" -Min 3 -Max 600

$playPackageName = ([Environment]::GetEnvironmentVariable("PLAY_PACKAGE_NAME", "Process") + "").Trim()
$playServiceAccountJson = ([Environment]::GetEnvironmentVariable("PLAY_SERVICE_ACCOUNT_JSON", "Process") + "").Trim()
$playServiceAccountJsonBase64 = ([Environment]::GetEnvironmentVariable("PLAY_SERVICE_ACCOUNT_JSON_BASE64", "Process") + "").Trim()
$hasPlayConfig = -not [string]::IsNullOrWhiteSpace($playPackageName) -or -not [string]::IsNullOrWhiteSpace($playServiceAccountJson) -or -not [string]::IsNullOrWhiteSpace($playServiceAccountJsonBase64)
if ($hasPlayConfig) {
  if ([string]::IsNullOrWhiteSpace($playPackageName)) {
    $errors.Add("PLAY_PACKAGE_NAME is required when Play Billing validation is configured.")
  }
  if ([string]::IsNullOrWhiteSpace($playServiceAccountJson) -and [string]::IsNullOrWhiteSpace($playServiceAccountJsonBase64)) {
    $errors.Add("PLAY_SERVICE_ACCOUNT_JSON or PLAY_SERVICE_ACCOUNT_JSON_BASE64 is required when Play Billing validation is configured.")
  }
  foreach ($productVar in @("PLAY_PRODUCT_ID_SMART", "PLAY_PRODUCT_ID_PRO", "PLAY_PRODUCT_ID_ELITE")) {
    $value = ([Environment]::GetEnvironmentVariable($productVar, "Process") + "").Trim()
    if ([string]::IsNullOrWhiteSpace($value)) {
      $errors.Add("$productVar is required when Play Billing validation is configured.")
    }
  }
}

if ($errors.Count -gt 0) {
  Write-Host "Invalid production configuration:" -ForegroundColor Red
  $errors | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
  exit 1
}

Write-Host "Production environment validated successfully." -ForegroundColor Green
