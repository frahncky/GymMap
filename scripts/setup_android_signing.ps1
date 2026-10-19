param([switch]$CreateIfMissing)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$keyDir = Join-Path $root 'android/keystore'
$keyPath = Join-Path $keyDir 'gymmap-upload.jks'
$propertiesPath = Join-Path $root 'android/key.properties'
if (Test-Path -LiteralPath $propertiesPath) {
  $existing = @{}
  Get-Content -LiteralPath $propertiesPath | ForEach-Object {
    if ($_ -match '^\s*([^#!][^=]*?)\s*=(.*)$') { $existing[$Matches[1]] = $Matches[2].Trim() }
  }
  if ($existing['storeFile']) {
    $existingStore = $existing['storeFile'].Replace('\:', ':').Replace('\\', '\')
    if (-not [IO.Path]::IsPathRooted($existingStore)) {
      $existingStore = Join-Path (Join-Path $root 'android/app') $existingStore
    }
    if (Test-Path -LiteralPath $existingStore) {
      Write-Host 'Existing configured upload key preserved.'
      exit 0
    }
  }
}
if (Test-Path -LiteralPath $keyPath) {
  if (-not (Test-Path -LiteralPath $propertiesPath)) {
    throw 'Existing key found. Restore its original key.properties; do not replace it.'
  }
  Write-Host 'Existing upload key preserved.'
  exit 0
}
if (-not $CreateIfMissing) {
  throw 'Upload key missing. Restore it, or use -CreateIfMissing only for a first publication.'
}
$keytool = Join-Path ${env:ProgramFiles} 'Android/Android Studio/jbr/bin/keytool.exe'
if (-not (Test-Path -LiteralPath $keytool)) { throw 'Android Studio keytool not found.' }
New-Item -ItemType Directory -Path $keyDir -Force | Out-Null
$randomBytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($randomBytes) } finally { $rng.Dispose() }
$secret = [Convert]::ToBase64String($randomBytes)
$env:GYMMAP_UPLOAD_PASSWORD = $secret
try {
  & $keytool -genkeypair -keystore $keyPath -storetype JKS -alias upload -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=DevIA, O=DevIA, C=BR' -storepass:env GYMMAP_UPLOAD_PASSWORD -keypass:env GYMMAP_UPLOAD_PASSWORD -noprompt
  if ($LASTEXITCODE -ne 0) { throw 'Upload key creation failed.' }
  if (Test-Path -LiteralPath $propertiesPath) {
    Copy-Item -LiteralPath $propertiesPath -Destination ($propertiesPath + '.backup')
  }
  $properties = "storePassword=$secret`nkeyPassword=$secret`nkeyAlias=upload`nstoreFile=../keystore/gymmap-upload.jks`n"
  [IO.File]::WriteAllText($propertiesPath, $properties, [Text.UTF8Encoding]::new($false))
} finally {
  Remove-Item Env:GYMMAP_UPLOAD_PASSWORD -ErrorAction SilentlyContinue
  $secret = $null
}
Write-Host 'Upload key created. Back up android/keystore and android/key.properties securely outside the repository.'
