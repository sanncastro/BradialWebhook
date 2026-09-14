[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-zA-Z0-9.-]+$')]
    [string]$PublicDomain,

    [ValidateRange(1, [int]::MaxValue)]
    [int]$DepartamentoUrgenteId = 46497,

    [ValidateLength(32, 512)]
    [string]$WebhookSecret,

    [string]$InstallRoot = 'C:\Services'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Abra o PowerShell como administrador e execute novamente.'
    }
}

function Read-SecretText([string]$Prompt) {
    $secure = Read-Host -Prompt $Prompt -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

function New-RandomSecret {
    $bytes = New-Object byte[] 32
    $generator = New-Object Security.Cryptography.RNGCryptoServiceProvider
    try {
        $generator.GetBytes($bytes)
        return ([BitConverter]::ToString($bytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $generator.Dispose()
    }
}

function Set-ServiceRecovery([string]$Name) {
    & sc.exe failure $Name reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Não foi possível configurar a recuperação de $Name." }
    & sc.exe failureflag $Name 1 | Out-Null
}

function Set-ServiceEnvironment(
    [string]$Name,
    [string[]]$Variables,
    [Security.Principal.SecurityIdentifier[]]$Readers
) {
    $key = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    Set-ItemProperty -Path $key -Name Environment -Type MultiString -Value $Variables

    $acl = Get-Acl $key
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) {
        [void]$acl.RemoveAccessRuleSpecific($rule)
    }

    $none = [Security.AccessControl.InheritanceFlags]::None
    $propagation = [Security.AccessControl.PropagationFlags]::None
    $allow = [Security.AccessControl.AccessControlType]::Allow
    $system = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
    $administrators = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')

    foreach ($sid in @($system, $administrators)) {
        $access = New-Object Security.AccessControl.RegistryAccessRule(
            $sid, 'FullControl', $none, $propagation, $allow)
        $acl.AddAccessRule($access)
    }

    foreach ($sid in $Readers) {
        $access = New-Object Security.AccessControl.RegistryAccessRule(
            $sid, 'ReadKey', $none, $propagation, $allow)
        $acl.AddAccessRule($access)
    }

    Set-Acl -Path $key -AclObject $acl
}

function Wait-HttpOk([string]$Uri, [int]$Seconds = 30) {
    $limit = (Get-Date).AddSeconds($Seconds)
    do {
        try {
            $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 5 `
                -Headers @{ 'ngrok-skip-browser-warning' = 'true' }
            if ($response.StatusCode -eq 200) { return }
        }
        catch { }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $limit)

    throw "O endereço não respondeu 200 dentro do prazo: $Uri"
}

Assert-Administrator

$projectRoot = Split-Path -Parent $PSScriptRoot
$projectFile = Join-Path $projectRoot 'BradialWebhook.csproj'
if (-not (Test-Path -LiteralPath $projectFile)) {
    throw "Projeto não encontrado: $projectFile"
}

$telegramToken = Read-SecretText 'Token do bot do Telegram'
if ([string]::IsNullOrWhiteSpace($telegramToken) -or -not $telegramToken.Contains(':')) {
    throw 'Token do Telegram inválido.'
}

$chatIdText = Read-Host 'Chat ID do Telegram'
$chatId = 0L
if (-not [long]::TryParse($chatIdText, [ref]$chatId) -or $chatId -eq 0) {
    throw 'Chat ID inválido.'
}

$ngrokToken = Read-SecretText 'Authtoken do ngrok'
if ([string]::IsNullOrWhiteSpace($ngrokToken)) {
    throw 'Authtoken do ngrok não informado.'
}

if ([string]::IsNullOrWhiteSpace($WebhookSecret)) {
    $WebhookSecret = New-RandomSecret
}

$appDirectory = Join-Path $InstallRoot 'BradialWebhook'
$ngrokDirectory = Join-Path $InstallRoot 'ngrok'
$ngrokExecutable = Join-Path $ngrokDirectory 'ngrok.exe'
$ngrokConfig = Join-Path $InstallRoot 'ngrok.yml'
$publishDirectory = Join-Path $env:TEMP 'BradialWebhook-publish'
$downloadZip = Join-Path $env:TEMP 'ngrok-windows-amd64.zip'
$downloadDirectory = Join-Path $env:TEMP 'ngrok-windows-amd64'

New-Item -ItemType Directory -Path $InstallRoot, $appDirectory, $ngrokDirectory -Force | Out-Null

if (Test-Path -LiteralPath $publishDirectory) {
    Remove-Item -LiteralPath $publishDirectory -Recurse -Force
}

& dotnet publish $projectFile -c Release -r win-x64 --self-contained true `
    -p:PublishSingleFile=true -p:IsTransformWebConfigDisabled=true -o $publishDirectory
if ($LASTEXITCODE -ne 0) { throw 'A publicação da aplicação falhou.' }

$appService = Get-Service -Name BradialWebhook -ErrorAction SilentlyContinue
if ($appService -and $appService.Status -ne 'Stopped') {
    Stop-Service BradialWebhook -Force
}
Copy-Item -Path (Join-Path $publishDirectory '*') -Destination $appDirectory -Force

if (-not (Test-Path -LiteralPath $ngrokExecutable)) {
    Invoke-WebRequest `
        -Uri 'https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip' `
        -OutFile $downloadZip -UseBasicParsing
    if (Test-Path -LiteralPath $downloadDirectory) {
        Remove-Item -LiteralPath $downloadDirectory -Recurse -Force
    }
    Expand-Archive -LiteralPath $downloadZip -DestinationPath $downloadDirectory -Force
    $downloadedExecutable = Join-Path $downloadDirectory 'ngrok.exe'
    $signature = Get-AuthenticodeSignature -LiteralPath $downloadedExecutable
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'ngrok') {
        throw 'A assinatura digital do executável ngrok não é válida.'
    }
    Copy-Item -LiteralPath $downloadedExecutable -Destination $ngrokExecutable -Force
}

$ngrokYaml = @"
version: "3"

endpoints:
  - name: bradial-webhook
    url: https://$PublicDomain
    upstream:
      url: http://127.0.0.1:5200
"@
Set-Content -LiteralPath $ngrokConfig -Value $ngrokYaml -Encoding UTF8

$appExecutable = Join-Path $appDirectory 'BradialWebhook.exe'
$appBinaryPath = '"{0}" --urls http://127.0.0.1:5200' -f $appExecutable
if (-not $appService) {
    New-Service -Name BradialWebhook -DisplayName 'Bradial Webhook' `
        -Description 'Notifica atendimentos urgentes no Telegram' `
        -BinaryPathName $appBinaryPath -StartupType Automatic | Out-Null
}
else {
    & sc.exe config BradialWebhook binPath= $appBinaryPath start= delayed-auto | Out-Null
}
& sc.exe config BradialWebhook obj= 'NT AUTHORITY\LocalService' password= '' start= delayed-auto | Out-Null

$allowedHosts = "localhost;127.0.0.1;$PublicDomain"
$appEnvironment = [string[]]@(
    'ASPNETCORE_ENVIRONMENT=Production',
    "Telegram__Token=$telegramToken",
    "Telegram__ChatId=$chatId",
    "Bradial__WebhookSecret=$WebhookSecret",
    "Bradial__DepartamentoUrgenteId=$DepartamentoUrgenteId",
    "AllowedHosts=$allowedHosts"
)
$localService = New-Object Security.Principal.SecurityIdentifier('S-1-5-19')
Set-ServiceEnvironment -Name BradialWebhook -Variables $appEnvironment -Readers @($localService)
Set-ServiceRecovery BradialWebhook

$ngrokService = Get-Service -Name ngrok -ErrorAction SilentlyContinue
if ($ngrokService -and $ngrokService.Status -ne 'Stopped') {
    Stop-Service ngrok -Force
}
$ngrokBinaryPath = '"{0}" service run --config "{1}"' -f $ngrokExecutable, $ngrokConfig
if (-not $ngrokService) {
    New-Service -Name ngrok -DisplayName 'ngrok' -Description 'Túnel público do BradialWebhook' `
        -BinaryPathName $ngrokBinaryPath -StartupType Automatic | Out-Null
}
else {
    & sc.exe config ngrok binPath= $ngrokBinaryPath start= delayed-auto | Out-Null
}
& sc.exe config ngrok obj= LocalSystem start= delayed-auto | Out-Null
Set-ServiceEnvironment -Name ngrok -Variables ([string[]]@("NGROK_AUTHTOKEN=$ngrokToken")) -Readers @()
Set-ServiceRecovery ngrok

Start-Service BradialWebhook
Wait-HttpOk 'http://127.0.0.1:5200/api/webhook/bradial'
Start-Service ngrok
Wait-HttpOk "https://$PublicDomain/api/webhook/bradial" 45

$escapedSecret = [Uri]::EscapeDataString($WebhookSecret)
Write-Host ''
Write-Host 'Instalação concluída.' -ForegroundColor Green
Write-Host 'Configure esta URL na Bradial:' -ForegroundColor Yellow
Write-Host "https://$PublicDomain/api/webhook/bradial?secret=$escapedSecret"
Write-Host ''
Write-Host 'Guarde essa URL em um gerenciador de senhas. Não a envie ao GitHub.'
