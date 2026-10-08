param(
    [string]$ConfigFile = (Join-Path (Split-Path -Parent $PSScriptRoot) '.env')
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRoot
. (Join-Path $PSScriptRoot 'backend-config.ps1')
$taskConfig = Read-OnlineConfig -ConfigFile $ConfigFile
& (Join-Path $PSScriptRoot 'check-online.ps1') -ConfigFile $taskConfig.ConfigFile -Probe
$taskFlutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($taskFlutterCommand) { $taskFlutter = $taskFlutterCommand.Source }
else { $taskFlutter = Join-Path $env:USERPROFILE '.cache\berik-tulga\flutter\bin\flutter.bat' }
if (!(Test-Path -LiteralPath $taskFlutter)) { throw 'Install Flutter and add it to PATH.' }
& $taskFlutter build apk --release "--dart-define-from-file=$($taskConfig.ConfigFile)"
if ($LASTEXITCODE -ne 0) { throw 'The online APK build failed.' }
$taskSource = Join-Path $taskRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (!(Test-Path -LiteralPath $taskSource)) { throw 'Flutter did not produce the release APK.' }
$taskOutputDirectory = Join-Path $taskRoot 'artifacts'
New-Item -ItemType Directory -Force -Path $taskOutputDirectory | Out-Null
$taskOutput = Join-Path $taskOutputDirectory 'berik-tulga-online.apk'
Copy-Item -LiteralPath $taskSource -Destination $taskOutput
$taskHash = (Get-FileHash -LiteralPath $taskOutput -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath ($taskOutput + '.sha256') -Value ($taskHash + '  berik-tulga-online.apk') -Encoding ascii
Write-Output ('Online APK: ' + $taskOutput)
Write-Output ('SHA-256: ' + $taskHash)
