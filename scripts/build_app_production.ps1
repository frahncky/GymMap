param(
  [ValidateSet("android-appbundle", "android-apk", "ios")]
  [string]$Target = "android-appbundle",
  [string]$DefineFile = "env/app.production.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DefineFile)) {
  throw "Define file not found: $DefineFile"
}

$config = Get-Content -LiteralPath $DefineFile -Raw | ConvertFrom-Json
$backendUri = $null
if (-not [Uri]::TryCreate($config.PLAN_BACKEND_BASE_URL, [UriKind]::Absolute, [ref]$backendUri) -or $backendUri.Scheme -ne 'https') {
  throw 'Production builds require an HTTPS PLAN_BACKEND_BASE_URL.'
}
if ("$($config.PLAN_PRODUCTION_MODE)" -ne 'true') {
  throw 'Production builds require PLAN_PRODUCTION_MODE=true.'
}
if ($Target -like 'android-*') {
  $root = Split-Path $PSScriptRoot -Parent
  $keyProperties = Join-Path $root 'android/key.properties'
  if (-not (Test-Path -LiteralPath $keyProperties)) {
    throw 'Release signing is missing. Run scripts/setup_android_signing.ps1 or restore your upload key.'
  }
  $signing = @{}
  Get-Content -LiteralPath $keyProperties | ForEach-Object {
    if ($_ -match '^\s*([^#!][^=]*?)\s*=(.*)$') { $signing[$Matches[1]] = $Matches[2].Trim() }
  }
  foreach ($name in @('storeFile','storePassword','keyAlias','keyPassword')) {
    if ([string]::IsNullOrWhiteSpace($signing[$name])) { throw "Missing signing property: $name" }
  }
  $store = $signing['storeFile'].Replace('\:', ':').Replace('\\', '\')
  if (-not [IO.Path]::IsPathRooted($store)) { $store = Join-Path (Join-Path $root 'android/app') $store }
  if (-not (Test-Path -LiteralPath $store)) { throw 'The configured upload keystore does not exist.' }
  if ($signing['keyAlias'] -eq 'androiddebugkey') { throw 'A production build cannot use the Android debug key.' }
}

switch ($Target) {
  "android-appbundle" {
    flutter build appbundle --release --dart-define-from-file="$DefineFile"
  }
  "android-apk" {
    flutter build apk --release --dart-define-from-file="$DefineFile"
  }
  "ios" {
    flutter build ipa --release --dart-define-from-file="$DefineFile"
  }
}
if ($LASTEXITCODE -ne 0) { throw "Flutter release build failed (exit $LASTEXITCODE)." }
