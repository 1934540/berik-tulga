param(
    [ValidateSet('android','web','check')][string]$Target = 'android',
    [string]$Device = '',
    [switch]$Online
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRoot
if ($Online) {
    . (Join-Path $PSScriptRoot 'backend-config.ps1')
    $null = Read-OnlineConfig -ConfigFile (Join-Path $taskRoot '.env')
}
$taskFlutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if ($taskFlutterCommand) { $taskFlutter = $taskFlutterCommand.Source }
else { $taskFlutter = Join-Path $env:USERPROFILE '.cache\berik-tulga\flutter\bin\flutter.bat' }
if (!(Test-Path -LiteralPath $taskFlutter)) { throw 'Install Flutter and add it to PATH.' }
if ($Target -eq 'check') {
    & $taskFlutter analyze
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & $taskFlutter test
    exit $LASTEXITCODE
}
$taskArguments = @('run')
if ($Target -eq 'web') { $taskArguments += @('-d','chrome') }
elseif ($Device) { $taskArguments += @('-d',$Device) }
if (Test-Path -LiteralPath '.env') { $taskArguments += '--dart-define-from-file=.env' }
& $taskFlutter @taskArguments
exit $LASTEXITCODE
