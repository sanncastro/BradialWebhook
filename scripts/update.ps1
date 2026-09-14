[CmdletBinding()]
param(
    [string]$InstallRoot = 'C:\Services'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Abra o PowerShell como administrador e execute novamente.'
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$projectFile = Join-Path $projectRoot 'BradialWebhook.csproj'
$publishDirectory = Join-Path $env:TEMP 'BradialWebhook-update'
$appDirectory = Join-Path $InstallRoot 'BradialWebhook'

if (-not (Get-Service BradialWebhook -ErrorAction SilentlyContinue)) {
    throw 'O serviço BradialWebhook não está instalado. Use install.ps1.'
}

if (Test-Path -LiteralPath $publishDirectory) {
    Remove-Item -LiteralPath $publishDirectory -Recurse -Force
}

& dotnet publish $projectFile -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true -p:IsTransformWebConfigDisabled=true -o $publishDirectory
if ($LASTEXITCODE -ne 0) { throw 'A publicação falhou; o serviço atual foi preservado.' }

Stop-Service BradialWebhook -Force
try {
    Copy-Item -Path (Join-Path $publishDirectory '*') -Destination $appDirectory -Force
}
finally {
    Start-Service BradialWebhook
}

$limit = (Get-Date).AddSeconds(30)
do {
    try {
        $response = Invoke-WebRequest -Uri 'http://127.0.0.1:5200/api/webhook/bradial' `
            -UseBasicParsing -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Host 'Atualização concluída e serviço validado.' -ForegroundColor Green
            exit 0
        }
    }
    catch { }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $limit)

throw 'O serviço foi atualizado, mas não respondeu na porta 5200. Execute diagnose.ps1.'
