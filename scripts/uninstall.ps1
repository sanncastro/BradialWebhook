[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [switch]$RemoveFiles,
    [string]$InstallRoot = 'C:\Services'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Abra o PowerShell como administrador e execute novamente.'
}

foreach ($name in @('ngrok', 'BradialWebhook')) {
    $service = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($service -and $PSCmdlet.ShouldProcess($name, 'Parar e remover Serviço do Windows')) {
        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name $name -Force
        }
        & sc.exe delete $name | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Não foi possível remover o serviço $name." }
    }
}

if ($RemoveFiles) {
    $resolvedRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
    if ($resolvedRoot -ne 'C:\Services') {
        throw 'Por segurança, a remoção automática de arquivos aceita apenas C:\Services.'
    }

    foreach ($path in @(
        (Join-Path $resolvedRoot 'BradialWebhook'),
        (Join-Path $resolvedRoot 'ngrok'),
        (Join-Path $resolvedRoot 'ngrok.yml')
    )) {
        if ((Test-Path -LiteralPath $path) -and $PSCmdlet.ShouldProcess($path, 'Remover')) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}

Write-Host 'Desinstalação concluída.' -ForegroundColor Green
