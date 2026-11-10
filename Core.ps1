# Local account management. No HTTP, logout, token refresh or package downloads.
# Dot-source this file; initialization is explicit so core logic can be tested.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CasHash([string]$Text) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

function Set-CasPrivateDirectory([string]$Path) {
    $null = [IO.Directory]::CreateDirectory($Path)
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $security = [Security.AccessControl.DirectorySecurity]::new()
    $security.SetAccessRuleProtection($true, $false)
    $inherit = [Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    foreach ($principal in @($sid, [Security.Principal.SecurityIdentifier]::new('S-1-5-18'))) {
        $security.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($principal, 'FullControl', $inherit, 'None', 'Allow'))
    }
    $directory = [IO.DirectoryInfo]::new($Path)
    if ($PSVersionTable.PSVersion.Major -ge 7) { [IO.FileSystemAclExtensions]::SetAccessControl($directory, $security) }
    else { $directory.SetAccessControl($security) }
}

function Initialize-Cas([string]$HomePath, [string]$VaultPath) {
    $script:CasHome = [IO.Path]::GetFullPath($HomePath).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $script:CasAuth = Join-Path $script:CasHome 'auth.json'
    $script:CasConfig = Join-Path $script:CasHome 'config.toml'
    if (-not $VaultPath) {
        $homeHash = (Get-CasHash $script:CasHome.ToLowerInvariant()).Substring(0,16)
        $VaultPath = Join-Path $env:LOCALAPPDATA "CodexLocalSwitcher\$homeHash"
    }
    $script:CasVault = [IO.Path]::GetFullPath($VaultPath)
    Set-CasPrivateDirectory $script:CasVault
    try { $script:CasLock = [IO.File]::Open((Join-Path $script:CasVault 'switcher.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'CAS|LOCK|Close the older switcher or the other copy of this window.' }
    $script:CasPump = { }
    $script:CasReport = { param($Message) }
}

function Close-Cas {
    if (Get-Variable CasLock -Scope Script -ErrorAction SilentlyContinue) {
        if ($null -ne $script:CasLock) { $script:CasLock.Dispose(); $script:CasLock = $null }
    }
}

function Write-CasAtomic([string]$Path, [byte[]]$Bytes) {
    $temp = Join-Path ([IO.Path]::GetDirectoryName($Path)) ([IO.Path]::GetRandomFileName())
    try {
        [IO.File]::WriteAllBytes($temp, $Bytes)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temp, $Path, [System.Management.Automation.Language.NullString]::Value) }
        else { [IO.File]::Move($temp, $Path) }
    } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Protect-CasData([byte[]]$Bytes) {
    return ,([Security.Cryptography.ProtectedData]::Protect($Bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
}
function Unprotect-CasData([byte[]]$Bytes) {
    return ,([Security.Cryptography.ProtectedData]::Unprotect($Bytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
}
function Save-CasSecret([string]$Path, [byte[]]$Bytes) { Write-CasAtomic $Path (Protect-CasData $Bytes) }
function Read-CasSecret([string]$Path) { return ,(Unprotect-CasData ([IO.File]::ReadAllBytes($Path))) }
function Get-CasSlotPath([int]$Slot) {
    if ($Slot -notin @(1,2)) { throw 'CAS|SLOT|Choose account 1 or 2.' }
    return (Join-Path $script:CasVault "account-$Slot.dpapi")
}

function Read-CasJwt([string]$Token) {
    $parts = $Token.Split('.')
    if ($parts.Length -ne 3) { throw 'CAS|FORMAT|Unsupported sign-in format. Use official ChatGPT sign-in.' }
    $payload = $parts[1].Replace('-', '+').Replace('_', '/')
    while ($payload.Length % 4) { $payload += '=' }
    return ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json)
}

function Get-CasAccount([byte[]]$Bytes) {
    try {
        $obj = [Text.Encoding]::UTF8.GetString($Bytes).TrimStart([char]0xFEFF) | ConvertFrom-Json
        if (-not $obj.PSObject.Properties['tokens']) { throw 'format' }
        foreach ($key in @('id_token', 'access_token', 'refresh_token')) {
            if (-not $obj.tokens.PSObject.Properties[$key] -or [string]::IsNullOrWhiteSpace([string]$obj.tokens.$key)) { throw 'format' }
        }
        $claims = Read-CasJwt ([string]$obj.tokens.id_token)
        if (-not $claims.PSObject.Properties['sub'] -or -not $claims.sub) { throw 'format' }
        $accountId = ''
        if ($obj.tokens.PSObject.Properties['account_id']) { $accountId = [string]$obj.tokens.account_id }
        # Matches the old PowerShell switcher's identity so existing slots import.
        $identity = Get-CasHash ([string]$claims.sub + '|' + $accountId)
        $email = ''
        if ($claims.PSObject.Properties['email']) { $email = [string]$claims.email }
        $email = [regex]::Replace($email, '[\p{Cc}\p{Cf}]', '')
        if ($email.Length -gt 120) { $email = $email.Substring(0,120) }
        if (-not $email) { $email = 'Account ' + $identity.Substring(0,10) }
        return [pscustomobject]@{ Id=$identity; Email=$email }
    } catch { throw 'CAS|FORMAT|No supported ChatGPT login found. Add the account through official sign-in.' }
}

function Read-CasLive {
    if (-not [IO.File]::Exists($script:CasAuth)) { throw 'CAS|NOAUTH|No local login file. Use Add / Sign in for the account.' }
    $bytes = [IO.File]::ReadAllBytes($script:CasAuth)
    $null = Get-CasAccount $bytes
    return ,$bytes
}

function Save-CasAccount([int]$Slot, [byte[]]$Bytes) {
    $incoming = Get-CasAccount $Bytes
    $target = Get-CasSlotPath $Slot
    if ([IO.File]::Exists($target)) {
        $old = Get-CasAccount (Read-CasSecret $target)
        if ($old.Id -ne $incoming.Id) { throw 'CAS|DIFFERENT|This slot belongs to another account. Select the empty slot, or sign in to the same account.' }
    }
    $otherPath = Get-CasSlotPath (3-$Slot)
    if ([IO.File]::Exists($otherPath)) {
        $other = Get-CasAccount (Read-CasSecret $otherPath)
        if ($other.Id -eq $incoming.Id) { throw 'CAS|DUPLICATE|This account is already in the other slot. Choose the other browser account during sign-in.' }
    }
    Save-CasSecret $target $Bytes
    return $incoming
}

function Get-CasStatus {
    $live = $null
    if ([IO.File]::Exists($script:CasAuth)) {
        try { $live = Get-CasAccount (Read-CasLive) } catch { }
    }
    $slots = @()
    foreach ($slot in @(1,2)) {
        $path = Get-CasSlotPath $slot
        $item = [pscustomobject]@{ Slot=$slot; State='empty'; Email=''; Id=''; IsCurrent=$false; Updated='' }
        if ([IO.File]::Exists($path)) {
            try {
                $account = Get-CasAccount (Read-CasSecret $path)
                $item.State='saved'; $item.Email=$account.Email; $item.Id=$account.Id
                $item.Updated=[IO.File]::GetLastWriteTime($path).ToString('yyyy-MM-dd HH:mm')
                $item.IsCurrent=($null -ne $live -and $live.Id -eq $account.Id)
            } catch { $item.State='unreadable' }
        }
        $slots += $item
    }
    return [pscustomobject]@{ Current=$live; Slots=$slots; Pending=[IO.File]::Exists((Join-Path $script:CasVault 'pending')); FileMode=(Test-CasFileMode) }
}

function Get-CasRoot([string]$Text) {
    $match = [regex]::Match($Text, '(?m)^[\t ]*\[')
    if ($match.Success) { return $Text.Substring(0,$match.Index) }
    return $Text
}
function Test-CasFileMode {
    if (-not [IO.File]::Exists($script:CasConfig)) { return $false }
    $root = Get-CasRoot ([IO.File]::ReadAllText($script:CasConfig))
    $entries = [regex]::Matches($root, '(?m)^[\t ]*cli_auth_credentials_store[\t ]*=.*$')
    return ($entries.Count -eq 1 -and $entries[0].Value -match '^\s*cli_auth_credentials_store\s*=\s*["'']file["'']\s*(#.*)?$')
}
function ConvertTo-CasFileConfig([string]$Text) {
    $root = Get-CasRoot $Text
    if ($root.Contains('"""') -or $root.Contains("'''")) { throw 'CAS|CONFIG|Root multiline TOML needs manual review; configuration was not changed.' }
    $entries = [regex]::Matches($root, '(?m)^[\t ]*cli_auth_credentials_store[\t ]*=.*$')
    $mentions = [regex]::Matches($root, '(?m)^[\t ]*[^#\r\n]*cli_auth_credentials_store[^\r\n]*=')
    if ($entries.Count -gt 1 -or $mentions.Count -ne $entries.Count) { throw 'CAS|CONFIG|Duplicate or quoted credential-store keys need manual review; configuration was not changed.' }
    if ($entries.Count -eq 1) {
        $entry=$entries[0]
        return ($Text.Substring(0,$entry.Index) + 'cli_auth_credentials_store = "file"' + $Text.Substring($entry.Index+$entry.Length))
    }
    return ('cli_auth_credentials_store = "file"' + "`r`n" + $Text)
}
function Set-CasFileMode {
    if (Test-CasFileMode) { return }
    $text=''
    if ([IO.File]::Exists($script:CasConfig)) { $text=[IO.File]::ReadAllText($script:CasConfig) }
    $updated=ConvertTo-CasFileConfig $text
    Write-CasAtomic $script:CasConfig ([Text.UTF8Encoding]::new($false).GetBytes($updated))
}

function Find-CasInstallation {
    $packages=@(Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue)
    if ($packages.Count -ne 1) { throw 'CAS|INSTALL|The OpenAI.Codex Windows app was not found uniquely. Install/open the official desktop app first.' }
    $pkg=$packages[0]
    $root=[string]$pkg.InstallLocation
    $apps=@(Get-StartApps | Where-Object { $_.AppID.StartsWith(([string]$pkg.PackageFamilyName+'!'), [StringComparison]::OrdinalIgnoreCase) })
    $aumid=''
    if ($apps.Count -eq 1) { $aumid=[string]$apps[0].AppID }
    else {
        [xml]$manifest=[IO.File]::ReadAllText((Join-Path $root 'AppxManifest.xml'))
        $app=@($manifest.SelectNodes('//*[local-name()="Applications"]/*[local-name()="Application"]') | Where-Object { $_.Executable -match '(?i)(chatgpt|codex)\.exe$' })
        if ($app.Count -eq 1) { $aumid=[string]$pkg.PackageFamilyName+'!'+[string]$app[0].Id }
    }
    if (-not $aumid) { throw 'CAS|INSTALL|The desktop launch entry is ambiguous. No account was changed.' }
    $cli=''
    foreach ($relative in @('app\resources\codex.exe','resources\codex.exe','codex.exe')) {
        $candidate=Join-Path $root $relative
        if ([IO.File]::Exists($candidate)) { $cli=$candidate; break }
    }
    if (-not $cli) {
        $command=Get-Command codex.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { $cli=$command.Source }
    }
    return [pscustomobject]@{ Root=$root; Aumid=$aumid; Cli=$cli }
}

function Test-CasProcess([string]$Name, [string]$Path, [string]$PackageRoot, [string]$Cli) {
    if ($Name -ieq 'codex-windows-sandbox-service') { return $false }
    if (-not $Path) { return $false }
    $underPackage=$Path.StartsWith(($PackageRoot.TrimEnd('\')+'\'), [StringComparison]::OrdinalIgnoreCase)
    $isCli=($Cli -and [string]::Equals($Path,$Cli,[StringComparison]::OrdinalIgnoreCase))
    $extensionCli=($Name -ieq 'codex' -and $Path -match '(?i)\\\.vscode(?:-insiders)?\\extensions\\openai\.chatgpt-[^\\]+\\')
    return ($underPackage -or $isCli -or $extensionCli)
}

function Get-CasProcesses($Installation) {
    $session=[Diagnostics.Process]::GetCurrentProcess().SessionId
    foreach ($process in @(Get-Process -ErrorAction Stop)) {
        # A short-lived unrelated process can exit during enumeration.
        try {
            if ($process.Id -eq $PID -or $process.SessionId -ne $session) { continue }
            $name=[string]$process.ProcessName
        } catch { continue }
        $path=''
        try { $path=[string]$process.Path } catch { }
        if (Test-CasProcess $name $path $Installation.Root $Installation.Cli) { Write-Output $process }
        elseif ($path -and $name -ieq 'codex') {
            throw ('CAS|EXTERNALCLI|Another Codex CLI installation is running, PID='+$process.Id+'. Close its terminal before switching. It will not be terminated automatically.')
        }
        elseif (-not $path -and $name -match '^(?i:codex|chatgpt)$') {
            throw ('CAS|UNKNOWNPROCESS|Cannot inspect '+$name+' PID='+$process.Id+'. Close that app manually; no process will be killed by name alone.')
        }
    }
}

function Wait-Cas([int]$Milliseconds) {
    $deadline=[DateTime]::UtcNow.AddMilliseconds($Milliseconds)
    while ([DateTime]::UtcNow -lt $deadline) { & $script:CasPump; Start-Sleep -Milliseconds 80 }
}

function Stop-CasDesktop($Installation, [switch]$Force) {
    $processes=@(Get-CasProcesses $Installation)
    foreach ($process in $processes) { try { if ($process.MainWindowHandle -ne [IntPtr]::Zero) { $null=$process.CloseMainWindow() } } catch { } }
    $deadline=[DateTime]::UtcNow.AddSeconds(10)
    while ([DateTime]::UtcNow -lt $deadline) {
        $processes=@(Get-CasProcesses $Installation)
        if ($processes.Count -eq 0) { return }
        Wait-Cas 200
    }
    if (-not $Force) {
        $names=($processes | ForEach-Object { $_.ProcessName+' PID='+$_.Id }) -join ', '
        throw ('CAS|RUNNING|'+$names)
    }
    # Revalidate paths for every pass; never stop arbitrary ChatGPT processes.
    for ($attempt=0; $attempt -lt 20; $attempt++) {
        $processes=@(Get-CasProcesses $Installation)
        if ($processes.Count -eq 0) { return }
        foreach ($process in $processes) { try { $process.Kill() } catch { } }
        Wait-Cas 200
    }
    throw 'CAS|RUNNING|Some verified Codex processes could not be closed. No account was changed.'
}

function Start-CasDesktop($Installation) {
    $null=Start-Process -FilePath 'explorer.exe' -ArgumentList ('shell:AppsFolder\'+$Installation.Aumid) -PassThru
}

function Wait-CasDesktopReady($Installation) {
    # First launch after an update can take substantially longer than six seconds.
    $deadline=[DateTime]::UtcNow.AddSeconds(35)
    while ([DateTime]::UtcNow -lt $deadline) {
        foreach ($process in @(Get-CasProcesses $Installation)) {
            try { if ($process.MainWindowHandle -ne [IntPtr]::Zero) { return } } catch { }
        }
        Wait-Cas 300
    }
    throw 'CAS|LAUNCH|No Codex desktop window appeared. Previous local login will be restored.'
}

function Sync-CasLive {
    # A cache left behind by keyring/auto is not authoritative. Preserve it in
    # the transaction, but never overwrite a newly signed-in account with it.
    if (-not (Test-CasFileMode)) { return }
    if (-not [IO.File]::Exists($script:CasAuth)) { return }
    $bytes=Read-CasLive
    $account=Get-CasAccount $bytes
    $matched=$false; $empty=0
    foreach ($slot in @(1,2)) {
        $path=Get-CasSlotPath $slot
        if (-not [IO.File]::Exists($path)) { if ($empty -eq 0) { $empty=$slot }; continue }
        $saved=Get-CasAccount (Read-CasSecret $path)
        if ($saved.Id -eq $account.Id) {
            # A fresh isolated sign-in may be newer than an old active cache.
            if ([IO.File]::GetLastWriteTimeUtc($script:CasAuth) -gt [IO.File]::GetLastWriteTimeUtc($path)) {
                Save-CasSecret $path $bytes
            }
            $matched=$true
        }
    }
    if (-not $matched) {
        if ($empty) { $null=Save-CasAccount $empty $bytes }
        else { throw 'CAS|UNSAVED|The local login is not one of the two saved accounts. Save/resolve it before switching.' }
    }
}

function Backup-CasTransaction {
    $record=@{ AuthExists=[IO.File]::Exists($script:CasAuth); ConfigExists=[IO.File]::Exists($script:CasConfig); Auth=''; Config='' }
    if ($record.AuthExists) { $record.Auth=[Convert]::ToBase64String([IO.File]::ReadAllBytes($script:CasAuth)) }
    if ($record.ConfigExists) { $record.Config=[Convert]::ToBase64String([IO.File]::ReadAllBytes($script:CasConfig)) }
    Save-CasSecret (Join-Path $script:CasVault 'transaction.dpapi') ([Text.Encoding]::UTF8.GetBytes(($record | ConvertTo-Json -Compress)))
    Write-CasAtomic (Join-Path $script:CasVault 'pending') ([byte[]]@(1))
}

function Restore-CasTransaction {
    $path=Join-Path $script:CasVault 'transaction.dpapi'
    if (-not [IO.File]::Exists($path)) { throw 'CAS|RECOVERY|No desktop-switch recovery snapshot is available yet.' }
    $record=[Text.Encoding]::UTF8.GetString((Read-CasSecret $path)) | ConvertFrom-Json
    # Recovery must remain possible even if the active cache is damaged, but
    # retain a valid newer active refresh token whenever it can be recognized.
    try { Sync-CasLive } catch { }
    foreach ($entry in @(@{ Path=$script:CasAuth; Exists=$record.AuthExists; Data=$record.Auth }, @{ Path=$script:CasConfig; Exists=$record.ConfigExists; Data=$record.Config })) {
        if ($entry.Exists) { Write-CasAtomic $entry.Path ([Convert]::FromBase64String($entry.Data)) }
        elseif ([IO.File]::Exists($entry.Path)) { [IO.File]::Delete($entry.Path) }
    }
    $pending=Join-Path $script:CasVault 'pending'
    if ([IO.File]::Exists($pending)) { [IO.File]::Delete($pending) }
}

function Invoke-CasSwitch([int]$Slot, $Installation, [switch]$Force) {
    $path=Get-CasSlotPath $Slot
    if (-not [IO.File]::Exists($path)) { throw 'CAS|EMPTY|Add this account before switching.' }
    $null=Get-CasAccount (Read-CasSecret $path)
    if ([IO.File]::Exists((Join-Path $script:CasVault 'pending'))) { throw 'CAS|PENDING|A previous switch was interrupted. Use Restore first.' }
    # Parse config BEFORE closing apps or writing credentials.
    $text=''
    if ([IO.File]::Exists($script:CasConfig)) { $text=[IO.File]::ReadAllText($script:CasConfig) }
    $null=ConvertTo-CasFileConfig $text
    & $script:CasReport 'Closing Codex...'
    Stop-CasDesktop $Installation -Force:$Force
    # Capture the latest refresh token after the app has stopped writing.
    Sync-CasLive
    $next=Read-CasSecret $path
    $target=Get-CasAccount $next
    $null=[IO.Directory]::CreateDirectory($script:CasHome)
    Backup-CasTransaction
    try {
        Set-CasFileMode
        Write-CasAtomic $script:CasAuth $next
        if ((Get-CasAccount (Read-CasLive)).Id -ne $target.Id) { throw 'CAS|VERIFY|The local account write did not verify.' }
        & $script:CasReport 'Opening Codex with the selected account...'
        Start-CasDesktop $Installation
        Wait-CasDesktopReady $Installation
        Wait-Cas 2500
        if (@(Get-CasProcesses $Installation).Count -eq 0) { throw 'CAS|LAUNCH|Codex did not stay open. Previous local login will be restored.' }
        $after=Read-CasLive
        if ((Get-CasAccount $after).Id -ne $target.Id) { throw 'CAS|VERIFY|Codex changed the local account unexpectedly.' }
        Save-CasSecret $path $after
        [IO.File]::Delete((Join-Path $script:CasVault 'pending'))
        return $target
    } catch {
        $originalError=$_
        try { Stop-CasDesktop $Installation; Restore-CasTransaction }
        catch { throw 'CAS|ROLLBACK|Switch failed and recovery needs attention. Close Codex and use Restore. The encrypted previous state is preserved.' }
        throw $originalError
    }
}

function Start-CasLoginProcess([string]$Cli, [string]$LoginHome, [switch]$DeviceCode) {
    $oldHome=[Environment]::GetEnvironmentVariable('CODEX_HOME','Process')
    $arguments=@('login')
    if ($DeviceCode) { $arguments+= '--device-auth' }
    try {
        [Environment]::SetEnvironmentVariable('CODEX_HOME',$LoginHome,'Process')
        return (Start-Process -FilePath $Cli -ArgumentList $arguments -WorkingDirectory $LoginHome -PassThru -WindowStyle Normal)
    } finally { [Environment]::SetEnvironmentVariable('CODEX_HOME',$oldHome,'Process') }
}

function Add-CasLogin([int]$Slot, $Installation, [switch]$DeviceCode) {
    if (-not $Installation.Cli -or -not [IO.File]::Exists($Installation.Cli)) { throw 'CAS|CLI|The official codex.exe was not found in the app. Update the official Codex app; no third-party package will be installed.' }
    $temp=Join-Path $script:CasVault ('login-'+[Guid]::NewGuid().ToString('N'))
    Set-CasPrivateDirectory $temp
    $process=$null
    try {
        [IO.File]::WriteAllText((Join-Path $temp 'config.toml'), 'cli_auth_credentials_store = "file"', [Text.UTF8Encoding]::new($false))
        $process=Start-CasLoginProcess $Installation.Cli $temp -DeviceCode:$DeviceCode
        & $script:CasReport 'Finish official sign-in in the browser / login window. Close that login window to cancel.'
        $deadline=[DateTime]::UtcNow.AddMinutes(10)
        while (-not $process.HasExited) {
            if ([DateTime]::UtcNow -gt $deadline) { try { $process.Kill() } catch { }; throw 'CAS|LOGIN|Sign-in timed out. Existing accounts were not changed.' }
            Wait-Cas 150
            $process.Refresh()
        }
        $process.WaitForExit()
        $loginPath=Join-Path $temp 'auth.json'
        if ($process.ExitCode -ne 0 -or -not [IO.File]::Exists($loginPath)) { throw 'CAS|LOGIN|Official sign-in was cancelled or failed. Existing accounts were not changed.' }
        return (Save-CasAccount $Slot ([IO.File]::ReadAllBytes($loginPath)))
    } finally {
        if ($null -ne $process) { $process.Dispose() }
        # Never log out: removing the temporary local cache does not revoke tokens.
        if ([IO.Directory]::Exists($temp)) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
