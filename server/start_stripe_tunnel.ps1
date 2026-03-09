param(
  [int]$Port = 4242
)

$ErrorActionPreference = 'Stop'

$serverDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Command ngrok -ErrorAction SilentlyContinue)) {
  Write-Error 'ngrok no está instalado o no está en PATH.'
}

if (-not (Test-Path (Join-Path $serverDir 'node_modules'))) {
  Write-Host 'Instalando dependencias de server...'
  Push-Location $serverDir
  npm install
  Pop-Location
}

Write-Host "Iniciando backend Stripe en puerto $Port..."
$backendProcess = Start-Process -FilePath 'npm.cmd' -ArgumentList 'run', 'dev' -WorkingDirectory $serverDir -PassThru

Start-Sleep -Seconds 2

Write-Host "Iniciando ngrok para http://localhost:$Port ..."
$ngrokProcess = Start-Process -FilePath 'ngrok' -ArgumentList 'http', $Port -PassThru

Start-Sleep -Seconds 2

try {
  $tunnels = Invoke-RestMethod -Uri 'http://127.0.0.1:4040/api/tunnels'
  $publicUrl = ($tunnels.tunnels | Where-Object { $_.proto -eq 'https' } | Select-Object -First 1).public_url
  if ($publicUrl) {
    Write-Host ''
    Write-Host 'Listo ✅'
    Write-Host "Backend local: http://localhost:$Port"
    Write-Host "Ngrok URL: $publicUrl"
    Write-Host ''
    Write-Host 'Usa este comando para Flutter/APK:'
    Write-Host "flutter build apk --release --dart-define=STRIPE_BACKEND_URL=$publicUrl --dart-define=STRIPE_PUBLISHABLE_KEY=TU_PK_TEST"
  }
} catch {
  Write-Warning 'No se pudo leer la URL de ngrok automáticamente. Revisa http://127.0.0.1:4040/api/tunnels'
}

Write-Host ''
Write-Host "PID backend: $($backendProcess.Id)"
Write-Host "PID ngrok: $($ngrokProcess.Id)"
Write-Host 'Para detenerlos: Stop-Process -Id <PID_BACKEND>,<PID_NGROK>'
