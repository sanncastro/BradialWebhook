[CmdletBinding()]
param(
    [switch]$ScanRepository
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest
$failed = $false

function Show-Check([string]$Name, [bool]$Ok, [string]$Details) {
    $color = if ($Ok) { 'Green' } else { 'Red' }
    $symbol = if ($Ok) { '[OK]' } else { '[FALHA]' }
    Write-Host "$symbol $Name - $Details" -ForegroundColor $color
    if (-not $Ok) { $script:failed = $true }
}

foreach ($name in @('BradialWebhook', 'ngrok')) {
    $service = Get-Service -Name $name -ErrorAction SilentlyContinue
    Show-Check "Serviço $name" ($null -ne $service -and $service.Status -eq 'Running') `
        $(if ($service) { $service.Status.ToString() } else { 'não instalado' })
}

try {
    $response = Invoke-WebRequest -Uri 'http://127.0.0.1:5200/api/webhook/bradial' `
        -UseBasicParsing -TimeoutSec 5
    Show-Check 'Endpoint local' ($response.StatusCode -eq 200) "HTTP $($response.StatusCode)"
}
catch {
    Show-Check 'Endpoint local' $false $_.Exception.Message
}

$ngrokConfig = 'C:\Services\ngrok.yml'
if (Test-Path -LiteralPath $ngrokConfig) {
    $configText = Get-Content -Raw -LiteralPath $ngrokConfig
    $domainMatch = [regex]::Match($configText, '(?m)^\s*url:\s*https://([^/\s]+)')
    if ($domainMatch.Success) {
        $publicUrl = "https://$($domainMatch.Groups[1].Value)/api/webhook/bradial"
        try {
            $response = Invoke-WebRequest -Uri $publicUrl -UseBasicParsing -TimeoutSec 15 `
                -Headers @{ 'ngrok-skip-browser-warning' = 'true' }
            Show-Check 'Endpoint público' ($response.StatusCode -eq 200) "HTTP $($response.StatusCode)"
        }
        catch {
            Show-Check 'Endpoint público' $false $_.Exception.Message
        }
    }
    else {
        Show-Check 'Configuração ngrok' $false 'domínio não encontrado'
    }
}
else {
    Show-Check 'Configuração ngrok' $false "$ngrokConfig não encontrado"
}

if ($ScanRepository) {
    $projectRoot = Split-Path -Parent $PSScriptRoot
    $extensions = @('.cs', '.json', '.yml', '.yaml', '.md', '.ps1', '.http', '.xml')
    $excluded = @('\bin\', '\obj\', '\publish\', '\.git\', '\.vs\')
    $tokenPattern = '[0-9]{8,12}:[A-Za-z0-9_-]{30,}'
    $assignmentPattern = '(?i)(authtoken|Telegram__Token|Bradial__WebhookSecret)\s*[:=]\s*["'']?([A-Za-z0-9_-]{24,})'
    $findings = New-Object System.Collections.Generic.List[string]

    foreach ($file in Get-ChildItem -LiteralPath $projectRoot -Recurse -File) {
        if ($extensions -notcontains $file.Extension) { continue }
        if ($excluded | Where-Object { $file.FullName.Contains($_) }) { continue }
        $lineNumber = 0
        foreach ($line in Get-Content -LiteralPath $file.FullName) {
            $lineNumber++
            if ($line -match $tokenPattern -or $line -match $assignmentPattern) {
                $relative = $file.FullName.Substring($projectRoot.Length + 1)
                $findings.Add("$relative`: linha $lineNumber")
            }
        }
    }

    Show-Check 'Varredura de segredos' ($findings.Count -eq 0) `
        $(if ($findings.Count -eq 0) { 'nenhum padrão suspeito encontrado' } else { $findings -join ', ' })
}

if ($failed) { exit 1 }
exit 0
