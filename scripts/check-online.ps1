param(
    [string]$ConfigFile = (Join-Path (Split-Path -Parent $PSScriptRoot) '.env'),
    [switch]$Probe
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'backend-config.ps1')
$taskConfig = Read-OnlineConfig -ConfigFile $ConfigFile
Write-Output 'Online configuration is valid; the key was not printed.'
if ($Probe) {
    try {
        $taskSettings = Invoke-RestMethod -Uri ($taskConfig.Url + '/auth/v1/settings') `
            -Headers @{ apikey = $taskConfig.PublicKey } -TimeoutSec 15
    } catch {
        throw 'Supabase Auth could not be reached with this public key. Check the project URL, key, and internet connection.'
    }
    Write-Output 'Supabase Auth is reachable.'
    Write-Output ('Email login enabled: ' + ($taskSettings.external.email -eq $true))
    Write-Output ('Phone login enabled: ' + ($taskSettings.external.phone -eq $true))
    Write-Output ('Public signup disabled: ' + ($taskSettings.disable_signup -eq $true))
    Write-Output 'This probe does not verify SQL migrations, password sign-in, or authenticated route synchronization.'
}
