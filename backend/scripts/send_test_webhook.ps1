param(
  [string]$BackendBaseUrl = "http://127.0.0.1:8080",
  [Parameter(Mandatory = $true)]
  [string]$ChargeId,
  [string]$EventId = "",
  [string]$WebhookToken = $env:WEBHOOK_TOKEN,
  [string]$WebhookSigningSecret = $env:WEBHOOK_SIGNING_SECRET
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WebhookToken)) {
  throw "WEBHOOK_TOKEN is required (parameter or environment)."
}
if ([string]::IsNullOrWhiteSpace($WebhookSigningSecret)) {
  throw "WEBHOOK_SIGNING_SECRET is required (parameter or environment)."
}

if ([string]::IsNullOrWhiteSpace($EventId)) {
  $EventId = "evt_" + [Guid]::NewGuid().ToString("N")
}

$bodyObject = @{
  eventId  = $EventId
  chargeId = $ChargeId
  status   = "paid"
}
$rawBody = $bodyObject | ConvertTo-Json -Compress

$timestamp = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$message = "$timestamp.$rawBody"

$hmac = New-Object System.Security.Cryptography.HMACSHA256
$hmac.Key = [Text.Encoding]::UTF8.GetBytes($WebhookSigningSecret)
$hashBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($message))
$hashHex = -join ($hashBytes | ForEach-Object { $_.ToString("x2") })

$headers = @{
  "X-Webhook-Token"     = $WebhookToken
  "X-Webhook-Timestamp" = "$timestamp"
  "X-Webhook-Signature" = "sha256=$hashHex"
  "X-Webhook-Event-Id"  = $EventId
  "Content-Type"        = "application/json"
}

$url = ($BackendBaseUrl.TrimEnd("/") + "/v1/webhooks/pix")
Write-Host "Sending webhook to $url"
$response = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $rawBody
$response | ConvertTo-Json -Depth 8
