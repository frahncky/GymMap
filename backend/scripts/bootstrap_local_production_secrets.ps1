param(
  [string]$EnvFile = "backend/.env.production",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $EnvFile)) {
  throw "Env file not found: $EnvFile"
}

function New-Base64UrlToken {
  param([int]$Bytes = 32)
  $buffer = New-Object byte[] $Bytes
  $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $rng.GetBytes($buffer)
  } finally {
    $rng.Dispose()
  }
  return [Convert]::ToBase64String($buffer).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Is-Placeholder {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
  if ($Value.Contains("<") -or $Value.Contains(">")) { return $true }
  $v = $Value.ToLowerInvariant()
  if ($v.Contains("strong_")) { return $true }
  if ($v.Contains("jwt_hs256_secret")) { return $true }
  return $false
}

$lines = Get-Content -Path $EnvFile -Encoding UTF8
$output = New-Object System.Collections.Generic.List[string]

$jwtSecret = New-Base64UrlToken -Bytes 48
$adminToken = New-Base64UrlToken -Bytes 48
$adminPassword = New-Base64UrlToken -Bytes 24

foreach ($line in $lines) {
  if ($line -match '^\s*JWT_HS256_SECRET=') {
    $current = $line.Substring($line.IndexOf('=') + 1).Trim()
    if ($Force -or (Is-Placeholder -Value $current)) {
      $output.Add("JWT_HS256_SECRET=$jwtSecret")
    } else {
      $output.Add($line)
    }
    continue
  }
  if ($line -match '^\s*ADMIN_API_TOKEN=') {
    $current = $line.Substring($line.IndexOf('=') + 1).Trim()
    if ($Force -or (Is-Placeholder -Value $current)) {
      $output.Add("ADMIN_API_TOKEN=$adminToken")
    } else {
      $output.Add($line)
    }
    continue
  }
  if ($line -match '^\s*AUTH_USERS_JSON=') {
    $current = $line.Substring($line.IndexOf('=') + 1).Trim()
    if ($Force -or (Is-Placeholder -Value $current)) {
      $output.Add("AUTH_USERS_JSON={""admin"":""$adminPassword""}")
    } else {
      $output.Add($line)
    }
    continue
  }
  if ($line -match '^\s*PIX_MP_DEFAULT_PAYER_EMAIL=') {
    $current = $line.Substring($line.IndexOf('=') + 1).Trim().Trim('<', '>')
    $output.Add("PIX_MP_DEFAULT_PAYER_EMAIL=$current")
    continue
  }
  $output.Add($line)
}

Set-Content -Path $EnvFile -Value $output -Encoding UTF8

Write-Host "Secrets bootstrap completed for $EnvFile" -ForegroundColor Green
Write-Host "Generated values (store securely):" -ForegroundColor Yellow
Write-Host " - JWT_HS256_SECRET=$jwtSecret"
Write-Host " - ADMIN_API_TOKEN=$adminToken"
Write-Host " - AUTH_USERS_JSON admin password=$adminPassword"
