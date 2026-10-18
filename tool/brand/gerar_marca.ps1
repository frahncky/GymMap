# Gera as imagens da marca do GymMap a partir de um único símbolo vetorial
# (tool/brand/gymmap_symbol.svg): pino do mapa, ícone do app e splash.
#
#   pwsh tool/brand/gerar_marca.ps1   (pinos em assets/brand; ícone e splash em tool/brand/out)
#   pwsh tool/brand/gerar_marca.ps1 -SoApp   (só o que fica em assets/brand: pinos e ícones)
#   dart run flutter_launcher_icons
#   dart run flutter_native_splash:create
#
# Usa o Microsoft Edge em modo headless para rasterizar, com fundo
# transparente. Cores da marca: grafite #1B222B (fundo do ícone e do splash).

param([switch]$SoApp)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$symbol = Join-Path $PSScriptRoot 'gymmap_symbol.svg'
$pinDir = Join-Path $root 'assets\brand'
$genDir = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Force -Path $pinDir, $genDir | Out-Null

$edge = @(
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge não encontrado.' }

$svg = Get-Content $symbol -Raw
# Mesma fonte do app (Plus Jakarta Sans) no nome do splash.
$fontUrl = 'file:///' + ((Join-Path $root 'assets\fonts\PlusJakartaSans-ExtraBold.ttf') -replace '\\', '/')
$fontSemiUrl = 'file:///' + ((Join-Path $root 'assets\fonts\PlusJakartaSans-SemiBold.ttf') -replace '\\', '/')
$mapSvg = Get-Content (Join-Path $PSScriptRoot 'folded_map.svg') -Raw
$work = Join-Path ([IO.Path]::GetTempPath()) 'gymmap-brand'
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Render([string]$dir, [string]$name, [int]$width, [int]$height, [string]$body, [string]$background = 'transparent') {
  $html = @"
<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;width:${width}px;height:${height}px;overflow:hidden;background:$background}
body{display:flex;flex-direction:column;align-items:center;justify-content:center}
svg{display:block}
@font-face{font-family:Jakarta;font-weight:800;src:url('$fontUrl')}
@font-face{font-family:Jakarta;font-weight:600;src:url('$fontSemiUrl')}
.word{font:800 150px Jakarta,'Segoe UI',Roboto,Arial,sans-serif;letter-spacing:-3px;color:#fff;margin-top:40px}
.word b{background:linear-gradient(90deg,#3FC6F0,#22B7A8,#7EDB5A);-webkit-background-clip:text;color:transparent}
</style></head><body>$body</body></html>
"@
  $page = Join-Path $work "$name.html"
  Set-Content -Path $page -Value $html -Encoding UTF8
  $target = Join-Path $dir "$name.png"
  & $edge --headless --disable-gpu --hide-scrollbars --default-background-color=00000000 `
    "--window-size=$width,$height" "--screenshot=$target" "file:///$($page -replace '\\','/')" 2>$null | Out-Null
  Start-Sleep -Milliseconds 300
  if (-not (Test-Path $target)) { throw "Falha ao gerar $name.png" }
  Write-Host "gerado: $target"
}

function Symbol([int]$height, [string]$source = $svg) {
  $width = [int]($height * 192 / 256)
  return $source -replace '<svg ', "<svg width=""$width"" height=""$height"" "
}

# Pino do mapa (proporção 192x256, em 2x para telas de alta densidade).
Render $pinDir 'pin' 384 512 (Symbol 512)

# Pinos por lotação: só o anel muda, nas cores do selo de lotação do app
# (GymMapColors.occupancy*), do tom claro ao tom do selo.
$levels = [ordered]@{
  low    = @('#7EDB5A', '#2A8F52')
  medium = @('#5FD6C8', '#13897E')
  high   = @('#FFD27A', '#E09F3E')
  full   = @('#FF8A73', '#CC4A37')
}
foreach ($level in $levels.Keys) {
  $from, $to = $levels[$level]
  $ring = "<linearGradient id=""ring"" x1=""0.15"" y1=""0"" x2=""0.85"" y2=""1"">" +
    "<stop offset=""0"" stop-color=""$from""/><stop offset=""1"" stop-color=""$to""/></linearGradient>"
  $levelSvg = [regex]::Replace($svg, '<linearGradient id="ring"[\s\S]*?</linearGradient>', $ring)
  Render $pinDir "pin_$level" 384 512 (Symbol 512 $levelSvg)
}

# Ícones das comodidades (painel da academia): verde-água da marca com um
# detalhe no laranja da mochila; 96 px para ~24 dp em telas 4x.
$teal = '#13897E'
$orange = '#EC6A2C'
$amenityIcons = [ordered]@{
  weights = @"
<rect x="1.5" y="9" width="2.5" height="6" rx="1" fill="$teal"/>
<rect x="4.5" y="6.5" width="3" height="11" rx="1.2" fill="$teal"/>
<rect x="16.5" y="6.5" width="3" height="11" rx="1.2" fill="$teal"/>
<rect x="20" y="9" width="2.5" height="6" rx="1" fill="$teal"/>
<rect x="7.5" y="11" width="9" height="2" rx="1" fill="$orange"/>
"@
  cardio = @"
<circle cx="15" cy="4.2" r="2.3" fill="$teal"/>
<g fill="none" stroke="$teal" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
  <path d="M13.6 8 11 13.4l3.4 2.6-1 5"/>
  <path d="M11 13.4 8.6 17.2l-3.8.6"/>
  <path d="M8.4 10.2 11.6 7.8l3.2 2.8 2.8.4"/>
</g>
<g fill="none" stroke="$orange" stroke-width="2" stroke-linecap="round"><path d="M2 9.4h3.6M1.6 13h3"/></g>
"@
  group_classes = @"
<g fill="$teal" opacity="0.55">
  <circle cx="5.2" cy="8.6" r="2.1"/><path d="M1 19.5c0-2.8 1.8-4.6 4.2-4.6s4.2 1.8 4.2 4.6z"/>
  <circle cx="18.8" cy="8.6" r="2.1"/><path d="M14.6 19.5c0-2.8 1.8-4.6 4.2-4.6s4.2 1.8 4.2 4.6z"/>
</g>
<circle cx="12" cy="6.8" r="2.7" fill="$teal"/>
<path d="M6.6 20.5c0-3.5 2.4-5.9 5.4-5.9s5.4 2.4 5.4 5.9z" fill="$teal"/>
<circle cx="12" cy="17.6" r="1.1" fill="$orange"/>
"@
  pool = @"
<g fill="none" stroke="$teal" stroke-width="1.9" stroke-linecap="round">
  <path d="M8 13V5.5a2 2 0 0 1 4 0"/><path d="M15 13V5.5a2 2 0 0 1 4 0"/>
  <path d="M8 8h7M8 11h7"/>
  <path d="M2 16.5c1.7 0 1.7-1.3 3.3-1.3s1.7 1.3 3.4 1.3 1.6-1.3 3.3-1.3 1.7 1.3 3.3 1.3 1.7-1.3 3.4-1.3 1.6 1.3 3.3 1.3"/>
</g>
<path d="M2 20.5c1.7 0 1.7-1.3 3.3-1.3s1.7 1.3 3.4 1.3 1.6-1.3 3.3-1.3 1.7 1.3 3.3 1.3 1.7-1.3 3.4-1.3 1.6 1.3 3.3 1.3" fill="none" stroke="$orange" stroke-width="1.9" stroke-linecap="round"/>
"@
  crossfit = @"
<path fill-rule="evenodd" fill="$teal" d="M9.4 2.6h5.2a3.8 3.8 0 0 1 3.8 3.8v2.2a3.8 3.8 0 0 1-1 2.6H6.6a3.8 3.8 0 0 1-1-2.6V6.4a3.8 3.8 0 0 1 3.8-3.8zM9.6 5a1.6 1.6 0 0 0-1.6 1.6v1.8a1.6 1.6 0 0 0 .2.8h7.6a1.6 1.6 0 0 0 .2-.8V6.6A1.6 1.6 0 0 0 14.4 5z"/>
<circle cx="12" cy="15.2" r="6.9" fill="$teal"/>
<rect x="7.6" y="20.4" width="8.8" height="1.8" rx="0.9" fill="$orange"/>
<path d="M8.2 15a3.9 3.9 0 0 1 2.6-3.2" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" opacity="0.6"/>
"@
  pilates = @"
<circle cx="12" cy="10.8" r="7.3" fill="$teal"/>
<path d="M7.4 9.2a5.1 5.1 0 0 1 3.8-3.4" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" opacity="0.7"/>
<rect x="2.5" y="19.6" width="19" height="2.2" rx="1.1" fill="$orange"/>
"@
  martial_arts = @"
<path d="M6 10.6V8a4.5 4.5 0 0 1 4.5-4.5h3A5.5 5.5 0 0 1 19 9v3.6a4.4 4.4 0 0 1-4.4 4.4H9.6A3.6 3.6 0 0 1 6 13.4z" fill="$teal"/>
<path d="M6.4 10.8a2.6 2.6 0 0 1 4.4 1.8v1.2" fill="none" stroke="#fff" stroke-width="1.7" stroke-linecap="round"/>
<rect x="7.4" y="17.6" width="9" height="3.8" rx="1.2" fill="$orange"/>
"@
  functional_dance = @"
<path d="M9 18.2V6.2l10-2.2v12" fill="none" stroke="$teal" stroke-width="2.2" stroke-linejoin="round"/>
<path d="M9 9.6l10-2.2" fill="none" stroke="$orange" stroke-width="2.2"/>
<ellipse cx="6.4" cy="18.2" rx="2.8" ry="2.4" fill="$teal"/>
<ellipse cx="16.4" cy="16" rx="2.8" ry="2.4" fill="$teal"/>
"@
  locker_room = @"
<path d="M5 21V8.5A4.5 4.5 0 0 1 9.5 4h1A4.5 4.5 0 0 1 15 8.5V9" fill="none" stroke="$teal" stroke-width="2.2" stroke-linecap="round"/>
<path d="M10.5 9h9l-1.4 2.6h-6.2z" fill="$teal"/>
<g fill="$orange"><circle cx="12.6" cy="14.4" r="1.1"/><circle cx="16.4" cy="14.4" r="1.1"/><circle cx="14.5" cy="17.4" r="1.1"/><circle cx="18.3" cy="17.4" r="1.1"/><circle cx="12.6" cy="20.2" r="1.1"/><circle cx="16.4" cy="20.2" r="1.1"/></g>
"@
  air_conditioning = @"
<g fill="none" stroke="$teal" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">
  <path d="M12 2.8v18.4M4 7.4l16 9.2M4 16.6l16-9.2"/>
  <path d="M9.4 4.4 12 7l2.6-2.6M9.4 19.6 12 17l2.6 2.6"/>
</g>
<circle cx="12" cy="12" r="2" fill="$orange"/>
"@
  parking = @"
<rect x="3" y="3" width="18" height="18" rx="4.5" fill="$teal"/>
<path d="M9.6 17V7.2h3.6a3 3 0 0 1 0 6H9.6" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
<rect x="3" y="18.4" width="18" height="2.6" rx="1.3" fill="$orange"/>
"@
  accessibility = @"
<circle cx="10.4" cy="4.2" r="2.1" fill="$teal"/>
<path d="M10.4 8v6.2h5.2l2.6 5" fill="none" stroke="$teal" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M10.4 10.8h4.4" fill="none" stroke="$teal" stroke-width="2.3" stroke-linecap="round"/>
<path d="M7.4 11.4a5.6 5.6 0 1 0 7.7 7.4" fill="none" stroke="$orange" stroke-width="2.1" stroke-linecap="round"/>
"@
  open_24h = @"
<path d="M20 12a8 8 0 1 1-2.4-5.7" fill="none" stroke="$teal" stroke-width="2.2" stroke-linecap="round"/>
<path d="M18.6 2.8v3.8h-3.8" fill="none" stroke="$teal" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M12 7.6V12l3 2" fill="none" stroke="$orange" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
"@
  personal_trainer = @"
<path d="M8.2 7.8h11.3a1.6 1.6 0 0 1 1.6 1.6v1.6a1.6 1.6 0 0 1-1.6 1.6h-7.3z" fill="$teal"/>
<circle cx="8.2" cy="13.6" r="5.7" fill="$teal"/>
<circle cx="8.2" cy="13.6" r="2" fill="#fff"/>
<path d="M4.4 9.4 2.8 5.2" fill="none" stroke="$orange" stroke-width="2" stroke-linecap="round"/>
"@
  fitness_assessment = @"
<rect x="4.8" y="4" width="14.4" height="17.6" rx="2.6" fill="$teal"/>
<rect x="8.4" y="2.4" width="7.2" height="3.8" rx="1.3" fill="$orange"/>
<path d="M8.4 13.2l2.4 2.4 4.8-5" fill="none" stroke="#fff" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>
"@
}
foreach ($name in $amenityIcons.Keys) {
  $icon = "<svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 24 24"" width=""96"" height=""96"">$($amenityIcons[$name])</svg>"
  Render $pinDir "amenity_$name" 96 96 $icon
}

# Ícones do menu inferior: contorno cinza (aba inativa) e preenchido no
# verde-água da marca com detalhe laranja (aba ativa).
$gray = '#5B6673'
$mapShape = 'M3 6.6 8.6 4.6 15.4 7 21 5v12.4l-5.6 2-6.8-2.4L3 19z'
$pinShape = 'M12 13.6s-3.1-2.8-3.1-5.3a3.1 3.1 0 0 1 6.2 0c0 2.5-3.1 5.3-3.1 5.3z'
$heartShape = 'M12 20.2s-7.4-4.5-9.3-9C1.2 7.7 3.4 4.2 7 4.2c2 0 3.4 1 5 2.8 1.6-1.8 3-2.8 5-2.8 3.6 0 5.8 3.5 4.3 7-1.9 4.5-9.3 9-9.3 9z'
$dropShape = 'M12 22s-7.2-6.3-7.2-12.1a7.2 7.2 0 0 1 14.4 0C19.2 15.7 12 22 12 22z'
$navIcons = [ordered]@{
  nav_map = @"
<path d="$mapShape" fill="none" stroke="$gray" stroke-width="1.9" stroke-linejoin="round"/>
<path d="M8.6 4.6v12.4M15.4 7v12.4" fill="none" stroke="$gray" stroke-width="1.6"/>
<path d="$pinShape" fill="#fff" stroke="$gray" stroke-width="1.6" stroke-linejoin="round"/>
"@
  nav_map_active = @"
<path d="$mapShape" fill="$teal" stroke="$teal" stroke-width="1.9" stroke-linejoin="round"/>
<path d="M8.6 4.6v12.4M15.4 7v12.4" fill="none" stroke="#fff" stroke-opacity="0.4" stroke-width="1.4"/>
<path d="$pinShape" fill="$orange" stroke="#fff" stroke-width="1.3" stroke-linejoin="round"/>
<circle cx="12" cy="8.4" r="1.1" fill="#fff"/>
"@
  nav_favorites = @"
<path d="$heartShape" fill="none" stroke="$gray" stroke-width="1.9" stroke-linejoin="round"/>
"@
  nav_favorites_active = @"
<path d="$heartShape" fill="$teal"/>
<path d="M6.2 8.6a2.8 2.8 0 0 1 2.4-2" fill="none" stroke="#fff" stroke-opacity="0.6" stroke-width="1.5" stroke-linecap="round"/>
<circle cx="16.6" cy="9.4" r="1.6" fill="$orange"/>
"@
  nav_community = @"
<g fill="none" stroke="$gray" stroke-width="1.7">
  <circle cx="5.4" cy="8.8" r="1.9"/><path d="M1.6 18.8c0-2.6 1.6-4.2 3.8-4.2 1 0 1.9.3 2.5.9"/>
  <circle cx="18.6" cy="8.8" r="1.9"/><path d="M22.4 18.8c0-2.6-1.6-4.2-3.8-4.2-1 0-1.9.3-2.5.9"/>
  <circle cx="12" cy="7.2" r="2.5"/><path d="M7.2 19.6c0-3.3 2.1-5.5 4.8-5.5s4.8 2.2 4.8 5.5z" stroke-linejoin="round"/>
</g>
"@
  nav_community_active = @"
<g fill="$teal" opacity="0.55">
  <circle cx="5.4" cy="8.8" r="2"/><path d="M1.4 19c0-2.7 1.7-4.4 4-4.4s4 1.7 4 4.4z"/>
  <circle cx="18.6" cy="8.8" r="2"/><path d="M14.6 19c0-2.7 1.7-4.4 4-4.4s4 1.7 4 4.4z"/>
</g>
<circle cx="12" cy="7.1" r="2.7" fill="$teal"/>
<path d="M6.8 20c0-3.5 2.3-5.8 5.2-5.8s5.2 2.3 5.2 5.8z" fill="$teal"/>
<circle cx="12" cy="17.4" r="1.1" fill="$orange"/>
"@
  nav_profile = @"
<path d="$dropShape" fill="none" stroke="$gray" stroke-width="1.8" stroke-linejoin="round"/>
<circle cx="12" cy="8.4" r="2.3" fill="none" stroke="$gray" stroke-width="1.6"/>
<path d="M8.1 14.6c.8-2 2.2-3 3.9-3s3.1 1 3.9 3" fill="none" stroke="$gray" stroke-width="1.6" stroke-linecap="round"/>
"@
  nav_profile_active = @"
<path d="$dropShape" fill="$teal"/>
<circle cx="12" cy="8.4" r="2.4" fill="#fff"/>
<path d="M7.9 14.8c.8-2.1 2.3-3.2 4.1-3.2s3.3 1.1 4.1 3.2z" fill="#fff"/>
<circle cx="12" cy="18.6" r="1" fill="$orange"/>
"@
}
foreach ($name in $navIcons.Keys) {
  $icon = "<svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 24 24"" width=""96"" height=""96"">$($navIcons[$name])</svg>"
  Render $pinDir $name 96 96 $icon
}

if ($SoApp) { return }

# Pino apoiado no mapa dobrado (a composição da marca), em HTML.
function PinOnMap([int]$pinHeight, [int]$mapWidth, [string]$extra = '', [int]$offsetY = 0) {
  $mapHeight = [int]($mapWidth * 0.4)
  $overlap = [int]($mapHeight * 0.6)
  $pin = (Symbol $pinHeight) -replace '<svg ', '<svg style="position:relative;z-index:2" '
  $map = $mapSvg -replace '<svg ', "<svg width=""$mapWidth"" height=""$mapHeight"" style=""margin-top:-$($overlap)px"" "
  return "<div style=""display:flex;flex-direction:column;align-items:center;margin-top:$($offsetY)px"">$pin$map$extra</div>"
}

# Ícone do app: fundo grafite, pino sobre o mapa (iOS e Android antigo).
Render $genDir 'app_icon' 1024 1024 (PinOnMap 560 700 '' -20) '#1B222B'

# Ícone adaptável do Android: a mesma composição dentro da área segura
# (círculo de ~61% que nenhum formato de ícone recorta).
Render $genDir 'app_icon_foreground' 1024 1024 (PinOnMap 470 540 '' -16)

# Splash: pino sobre o mapa e o nome.
Render $genDir 'splash_logo' 1152 1152 (PinOnMap 520 620 '<div class="word">Gym<b>Map</b></div>')

# Splash do Android 12+: o sistema mostra só um círculo (2/3 da imagem) e põe
# o "branding" no rodapé, longe do ícone. Por isso o nome vai dentro da
# própria imagem, logo abaixo do pino com o mapa, tudo dentro do círculo.
$a12Name = '<div class="word" style="font-size:96px;margin-top:14px;letter-spacing:-2px">Gym<b>Map</b></div>'
Render $genDir 'splash_android12' 1152 1152 (PinOnMap 290 380 $a12Name 10)

# Loja (Google Play): ícone 512x512 e imagem de destaque 1024x500.
$storeDir = Join-Path $genDir 'store'
New-Item -ItemType Directory -Force -Path $storeDir | Out-Null
Render $storeDir 'play_icon_512' 512 512 (PinOnMap 280 340 '' -10) '#1B222B'

function FeatureGraphic([string]$tagline) {
  $art = PinOnMap 300 360
  return @"
<div style="width:1024px;height:500px;display:flex;align-items:center;justify-content:center;gap:64px;
  background:radial-gradient(circle at 25% 40%,#2E3A46 0%,#1B222B 70%)">
  <div style="flex:0 0 auto">$art</div>
  <div style="max-width:520px">
    <div class="word" style="margin:0;font-size:104px;letter-spacing:-3px">Gym<b>Map</b></div>
    <div style="font:600 31px Jakarta,'Segoe UI',sans-serif;color:#E8EDF2;line-height:1.25;margin-top:14px">$tagline</div>
  </div>
</div>
"@
}
Render $storeDir 'feature_graphic_pt' 1024 500 (FeatureGraphic 'Academias perto de você, com a lotação em tempo real.')
Render $storeDir 'feature_graphic_en' 1024 500 (FeatureGraphic 'Gyms near you, with live occupancy.')
