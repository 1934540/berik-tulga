function Read-OnlineConfig {
    param([Parameter(Mandatory)][string]$ConfigFile)
    if (!(Test-Path -LiteralPath $ConfigFile -PathType Leaf)) {
        throw 'Online configuration is missing. Copy .env.example to .env and fill in the Supabase project URL and public key.'
    }
    $taskValues = @{}
    foreach ($taskLine in Get-Content -LiteralPath $ConfigFile) {
        $taskLine = $taskLine.Trim()
        if (!$taskLine -or $taskLine.StartsWith('#')) { continue }
        if ($taskLine -notmatch '^([A-Z][A-Z0-9_]*)\s*=\s*(.*)$') {
            throw 'Expected KEY=value entries in the online configuration file.'
        }
        $taskName = $Matches[1]
        $taskValue = $Matches[2].Trim()
        if ($taskValue.Length -ge 2 -and (
            ($taskValue.StartsWith('"') -and $taskValue.EndsWith('"')) -or
            ($taskValue.StartsWith("'") -and $taskValue.EndsWith("'")))) {
            $taskValue = $taskValue.Substring(1, $taskValue.Length - 2)
        }
        if ($taskValues.ContainsKey($taskName)) { throw "Duplicate configuration entry: $taskName" }
        $taskValues[$taskName] = $taskValue
    }
    if ($taskValues['OFFLINE_ONLY'] -cne 'false') {
        throw 'Set OFFLINE_ONLY=false to enable cloud authentication and synchronization.'
    }
    $taskUrl = $null
    if (![Uri]::TryCreate($taskValues['SUPABASE_URL'], [UriKind]::Absolute, [ref]$taskUrl) -or
        $taskUrl.Scheme -notin @('https', 'http') -or
        ($taskUrl.Scheme -eq 'http' -and !$taskUrl.IsLoopback) -or
        $taskUrl.UserInfo -or $taskUrl.Query -or $taskUrl.Fragment) {
        throw 'SUPABASE_URL must be the HTTPS project URL (HTTP is allowed only for local development).'
    }
    $taskKey = $taskValues['SUPABASE_ANON_KEY']
    if (!$taskKey) { throw 'SUPABASE_ANON_KEY is missing. Use the public publishable or anon key.' }
    if (!$taskKey.StartsWith('sb_publishable_')) {
        try {
            $taskParts = $taskKey.Split('.')
            if ($taskParts.Count -ne 3) { throw 'Not an anon token' }
            $taskPayload = $taskParts[1].Replace('-', '+').Replace('_', '/')
            $taskPayload = $taskPayload.PadRight($taskPayload.Length + ((4 - $taskPayload.Length % 4) % 4), '=')
            $taskClaims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($taskPayload)) | ConvertFrom-Json
            if ($taskClaims.role -cne 'anon') { throw 'Not an anon token' }
        } catch {
            throw 'Use only a public publishable or anon key. Secret and service-role keys must never be embedded in the app.'
        }
    }
    return @{
        Url = $taskUrl.AbsoluteUri.TrimEnd('/')
        PublicKey = $taskKey
        ConfigFile = (Resolve-Path -LiteralPath $ConfigFile).Path
    }
}
