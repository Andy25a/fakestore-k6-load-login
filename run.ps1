[CmdletBinding()]
param(
    [switch]$SkipOpenReport,
    [switch]$NoWebDashboard
)

$ErrorActionPreference = "Stop"

# UTF-8 en consola: k6 imprime simbolos (µs, marcas de check) en UTF-8; sin esto CMD muestra mojibake (p. ej. Ô£ô).
try {
    cmd /c "chcp 65001 >nul"
} catch { }
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$reportDir = Join-Path $projectRoot "reports"
$htmlDir = Join-Path $reportDir "html"
$summaryDir = Join-Path $reportDir "summaries"
$dashboardDir = Join-Path $reportDir "dashboard"
$logDir = Join-Path $reportDir "logs"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
New-Item -ItemType Directory -Force -Path $htmlDir | Out-Null
New-Item -ItemType Directory -Force -Path $summaryDir | Out-Null
New-Item -ItemType Directory -Force -Path $dashboardDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$jsonSummary = Join-Path $summaryDir "k6-summary-$timestamp.json"
$htmlReport = Join-Path $htmlDir "k6-report-$timestamp.html"
$dashboardExportHtml = Join-Path $dashboardDir "k6-dashboard-export-$timestamp.html"
$logFile = Join-Path $logDir "run-$timestamp.log"

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "==== $Message ====" -ForegroundColor Cyan
}

Write-Section "Validaciones previas"
$k6Cmd = Get-Command k6 -ErrorAction SilentlyContinue
if (-not $k6Cmd) {
    $k6Fallback = "C:\Program Files\k6\k6.exe"
    if (Test-Path $k6Fallback) {
        $k6Cmd = @{ Source = $k6Fallback }
    } else {
        throw "No se encontró k6 en PATH. Instala k6 y vuelve a ejecutar."
    }
}

Write-Section "Ejecucion de prueba de carga"
$scriptPath = ".\scripts\login-load-test.js"
$useWebDashboard = -not $NoWebDashboard

if ($useWebDashboard) {
    $dashboardPortBusy = $false
    try {
        $listener = Get-NetTCPConnection -LocalPort 5665 -State Listen -ErrorAction SilentlyContinue
        if ($listener) {
            $dashboardPortBusy = $true
        }
    } catch {
        $dashboardPortBusy = $false
    }

    if ($dashboardPortBusy) {
        $useWebDashboard = $false
        Write-Host "Puerto 5665 ocupado: se ejecuta sin dashboard web para no fallar la ejecución." -ForegroundColor Yellow
    }
}

if ($useWebDashboard) {
    $env:K6_WEB_DASHBOARD = "true"
    $env:K6_WEB_DASHBOARD_OPEN = "true"
    $env:K6_WEB_DASHBOARD_EXPORT = $dashboardExportHtml
    Write-Host "Dashboard web k6 activado (http://127.0.0.1:5665)." -ForegroundColor Cyan
    Write-Host "Se abre automaticamente al ejecutar." -ForegroundColor DarkGray
    Write-Host "Al terminar, k6 exporta un HTML con graficas a: $dashboardExportHtml" -ForegroundColor Cyan
    Write-Host "Para evitar bloqueos, no dejes pestañas del dashboard abiertas tras finalizar." -ForegroundColor DarkGray
} else {
    Remove-Item Env:K6_WEB_DASHBOARD -ErrorAction SilentlyContinue
    Remove-Item Env:K6_WEB_DASHBOARD_OPEN -ErrorAction SilentlyContinue
    Remove-Item Env:K6_WEB_DASHBOARD_EXPORT -ErrorAction SilentlyContinue
    Write-Host "Dashboard web desactivado por parametro -NoWebDashboard." -ForegroundColor DarkGray
}

Write-Host "k6 con progreso normal (filtrando repeticiones al 100%)."
# --no-color + NO_COLOR: evita secuencias ANSI en el log (sin ESC [32m en el archivo).
$k6CmdLine = "`"$($k6Cmd.Source)`" run --no-color -e REPORT_TIMESTAMP=$timestamp -e REPORT_SUMMARY_FILE=reports/summaries/k6-summary-$timestamp.json -e REPORT_HTML_FILE=reports/html/k6-report-$timestamp.html `"$scriptPath`""
$utf8AndNoColorPrefix = "chcp 65001 >nul && set NO_COLOR=1 && set K6_NO_COLOR=1 && "
$dashboardEnvPrefix = ""
if ($useWebDashboard) {
    $dashboardEnvPrefix = "set `"K6_WEB_DASHBOARD=true`" && set `"K6_WEB_DASHBOARD_OPEN=$($env:K6_WEB_DASHBOARD_OPEN)`" && set `"K6_WEB_DASHBOARD_EXPORT=$dashboardExportHtml`" && "
}
$seenFinalProgress = $false
$seenFinalScenario = $false
$ansiPattern = "$([char]27)\[[0-9;?]*[ -/]*[@-~]"
cmd /c "cd /d `"$projectRoot`" && $utf8AndNoColorPrefix$dashboardEnvPrefix$k6CmdLine 2>&1" |
ForEach-Object {
    $line = $_.ToString()
    $cleanLine = [regex]::Replace($line, $ansiPattern, '')
    if ([string]::IsNullOrWhiteSpace($cleanLine)) {
        return
    }
    $skip = $false

    if ($cleanLine -match '^running \(.+\), 000\/030 VUs, \d+ complete and 0 interrupted iterations$') {
        if ($seenFinalProgress) {
            $skip = $true
        } else {
            $seenFinalProgress = $true
        }
    }

    if ($cleanLine -match '^login_load .* \[ 100% \] 000\/030 VUs') {
        if ($seenFinalScenario) {
            $skip = $true
        } else {
            $seenFinalScenario = $true
        }
    }

    if (-not $skip) {
        $cleanLine
    }
} | Tee-Object -FilePath $logFile
$k6Exit = $LASTEXITCODE

Remove-Item Env:K6_WEB_DASHBOARD -ErrorAction SilentlyContinue
Remove-Item Env:K6_WEB_DASHBOARD_OPEN -ErrorAction SilentlyContinue
Remove-Item Env:K6_WEB_DASHBOARD_EXPORT -ErrorAction SilentlyContinue

if ($k6Exit -ne 0) {
    throw "La ejecución falló (código $k6Exit). Revisa el log: $logFile"
}

Write-Section "Generacion de reporte HTML"
$htmlCmd = "k6-html-reporter `"$jsonSummary`" -o `"$htmlReport`""
if (Get-Command k6-html-reporter -ErrorAction SilentlyContinue) {
    cmd /c "cd /d `"$projectRoot`" && chcp 65001 >nul && $htmlCmd 2>&1" | Tee-Object -FilePath $logFile -Append
} else {
    Write-Host "k6-html-reporter no encontrado. El HTML se genera desde el propio script de k6." -ForegroundColor Yellow
}

Write-Section "Resultado"
Write-Host "Ejecucion completada correctamente." -ForegroundColor Green
Write-Host "Resumen JSON : reports\summaries\k6-summary-$timestamp.json"
Write-Host "Reporte HTML (k6-reporter desde el script): reports\html\k6-report-$timestamp.html"
if ($useWebDashboard) {
    if (Test-Path -LiteralPath $dashboardExportHtml) {
        Write-Host "Reporte HTML (dashboard k6, con graficas): reports\dashboard\k6-dashboard-export-$timestamp.html" -ForegroundColor Green
    } else {
        Write-Host "No se genero el export del dashboard (revisa version de k6 o cierra el navegador del dashboard si k6 no termina)." -ForegroundColor Yellow
    }
}
Write-Host "Log de ejecucion: reports\logs\run-$timestamp.log"

if (-not $SkipOpenReport) {
    $deadline = (Get-Date).AddSeconds(15)
    while (-not (Test-Path -LiteralPath $htmlReport) -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 200
    }
    if (Test-Path -LiteralPath $htmlReport) {
        $uri = (Resolve-Path -LiteralPath $htmlReport).Path
        Write-Host "Abriendo reporte HTML en el navegador predeterminado..." -ForegroundColor Cyan
        Start-Process $uri
    } else {
        Write-Host "No se encontro el HTML en: $htmlReport (revisa el log de k6)." -ForegroundColor Yellow
    }
}
