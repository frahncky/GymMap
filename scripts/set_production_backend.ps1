param(
  [Parameter(Mandatory = $true)][string]$BaseUrl,
  [string]$DefineFile = 'env/app.production.json'
)
$ErrorActionPreference = 'Stop'
$uri = $null
if (-not [Uri]::TryCreate($BaseUrl.Trim(), [UriKind]::Absolute, [ref]$uri) -or
    $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
    $uri.AbsolutePath -ne '/') {
  throw 'Use the real public HTTPS origin of the deployed API, without credentials, path or query.'
}
if (-not (Test-Path -LiteralPath $DefineFile)) { throw "Define file not found: $DefineFile" }
$config = Get-Content -LiteralPath $DefineFile -Raw | ConvertFrom-Json
$config.PLAN_BACKEND_BASE_URL = $uri.GetLeftPart([UriPartial]::Authority)
$config.PLAN_PRODUCTION_MODE = 'true'
[IO.File]::WriteAllText(
  $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DefineFile),
  ($config | ConvertTo-Json),
  [Text.UTF8Encoding]::new($false)
)
Write-Host 'Production API origin updated. Run scripts/check_production_api.ps1 before building.'
