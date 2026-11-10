# Executable offline core tests; all accounts are synthetic, no Codex is touched.
# On non-Windows only the OS encryption/ACL boundary is mocked. On Windows,
# real DPAPI and private-directory ACLs are exercised as well.
#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if ($env:OS -eq 'Windows_NT') { Add-Type -AssemblyName System.Security }
. (Join-Path $PSScriptRoot 'Core.ps1')
$script:Passed=0
function Assert-Test([bool]$Condition,[string]$Name) {
    if (-not $Condition) { throw ('FAILED: '+$Name) }
    $script:Passed++; Write-Host ('PASS  '+$Name) -ForegroundColor Green
}
function Assert-Throws([scriptblock]$Action,[string]$Code,[string]$Name) {
    $caught=$false
    try { & $Action } catch { $caught=($_.Exception.Message -like ('CAS|'+$Code+'|*')) }
    Assert-Test $caught $Name
}
function New-TestAuth([string]$Who,[string]$Refresh='refresh-1') {
    $claims=@{ sub=$Who; email=($Who+'@example.test') } | ConvertTo-Json -Compress
    $part=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claims)).TrimEnd('=').Replace('+','-').Replace('/','_')
    $json=@{tokens=@{id_token=('header.'+$part+'.signature');access_token='synthetic-access';refresh_token=$Refresh;account_id=('workspace-'+$Who)}} | ConvertTo-Json -Depth 4 -Compress
    return ,([Text.Encoding]::UTF8.GetBytes($json))
}
if ($env:OS -ne 'Windows_NT') {
    Write-Host 'Linux: DPAPI/ACL boundary mocked. Files, account logic, transactions and process classification use the real core.'
    function Set-CasPrivateDirectory([string]$Path) { $null=[IO.Directory]::CreateDirectory($Path) }
    function Protect-CasData([byte[]]$Bytes) { return ,([Text.Encoding]::UTF8.GetBytes(('TEST:'+ [Convert]::ToBase64String($Bytes)))) }
    function Unprotect-CasData([byte[]]$Bytes) {
        $value=[Text.Encoding]::UTF8.GetString($Bytes)
        if (-not $value.StartsWith('TEST:')) { throw 'Not a test envelope' }
        return ,([Convert]::FromBase64String($value.Substring(5)))
    }
}
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('cas-tests-'+[Guid]::NewGuid().ToString('N'))
$testHome=Join-Path $testRoot 'home'
$vault=Join-Path $testRoot 'vault'
$null=[IO.Directory]::CreateDirectory($testHome)
try {
    Initialize-Cas $testHome $vault
    $a=New-TestAuth 'alice'
    $b=New-TestAuth 'bob'
    $freshA=New-TestAuth 'alice' 'refresh-NEW'
    Assert-Test ((Get-CasAccount $a).Email -eq 'alice@example.test') 'Decode identity without exposing credentials'
    Assert-Test ((Get-CasAccount $a).Id -eq (Get-CasAccount $freshA).Id) 'Identity survives token refresh'
    Assert-Throws { Get-CasAccount ([Text.Encoding]::UTF8.GetBytes('{broken')) } 'FORMAT' 'Malformed auth is rejected'
    Assert-Test ((Get-CasStatus).Slots[0].State -eq 'empty') 'Empty slot state'
    $null=Save-CasAccount 1 $a
    $stored=[IO.File]::ReadAllBytes((Get-CasSlotPath 1))
    Assert-Test ([Text.Encoding]::UTF8.GetString($stored) -notlike '*alice@example.test*') 'Saved envelope has no plaintext email'
    Assert-Test ((Get-CasAccount (Read-CasSecret (Get-CasSlotPath 1))).Email -eq 'alice@example.test') 'Saved account round trip'
    Assert-Throws { Save-CasAccount 2 $a } 'DUPLICATE' 'Duplicate account blocked'
    Assert-Throws { Save-CasAccount 1 $b } 'DIFFERENT' 'Different identity cannot replace a filled slot'
    $null=Save-CasAccount 2 $b
    Assert-Test ((Get-CasStatus).Slots[1].Email -eq 'bob@example.test') 'Second account displayed'
    foreach ($source in @('', "model = 'x'`n", "# comment`n[profiles.dev]`nmodel = 'x'`n")) {
        $result=ConvertTo-CasFileConfig $source
        Assert-Test ($result.EndsWith($source) -and $result.StartsWith('cli_auth_credentials_store = "file"')) 'Root file setting inserted without changing other text'
    }
    $source="cli_auth_credentials_store = 'keyring' # comment`nmodel = 'x'`n[foo]`na=1`n"
    Assert-Test ((ConvertTo-CasFileConfig $source) -eq "cli_auth_credentials_store = `"file`"`nmodel = 'x'`n[foo]`na=1`n") 'Replace only root credential-store entry'
    Assert-Throws { ConvertTo-CasFileConfig "cli_auth_credentials_store='file'`ncli_auth_credentials_store='auto'" } 'CONFIG' 'Duplicate config keys fail before mutation'
    Assert-Throws { ConvertTo-CasFileConfig 'description = """hello"""' } 'CONFIG' 'Complex multiline root config left intact'
    Assert-Throws { ConvertTo-CasFileConfig '"cli_auth_credentials_store" = "auto"' } 'CONFIG' 'Quoted config key left intact'
    Set-CasFileMode
    Assert-Test (Test-CasFileMode) 'Generated config recognized as file mode'
    Write-CasAtomic $script:CasAuth $a
    Assert-Test ((Get-CasStatus).Slots[0].IsCurrent) 'Current local account matched to card'
    $null=Save-CasAccount 1 $freshA
    [IO.File]::SetLastWriteTimeUtc($script:CasAuth,[DateTime]::UtcNow.AddMinutes(-2))
    Sync-CasLive
    Assert-Test ([Text.Encoding]::UTF8.GetString((Read-CasSecret (Get-CasSlotPath 1))) -like '*refresh-NEW*') 'Old live cache cannot overwrite a newer sign-in'
    Write-CasAtomic $script:CasAuth (New-TestAuth 'alice' 'refresh-LATEST')
    [IO.File]::SetLastWriteTimeUtc($script:CasAuth,[DateTime]::UtcNow.AddMinutes(1))
    Sync-CasLive
    Assert-Test ([Text.Encoding]::UTF8.GetString((Read-CasSecret (Get-CasSlotPath 1))) -like '*refresh-LATEST*') 'New live refresh token saved before switching'
    $pkg='C:\Program Files\WindowsApps\OpenAI.Codex_1'
    Assert-Test (Test-CasProcess 'ChatGPT' ($pkg+'\app\ChatGPT.exe') $pkg '') 'Packaged integrated desktop detected by path'
    Assert-Test (-not (Test-CasProcess 'ChatGPT' 'C:\Other\ChatGPT.exe' $pkg '')) 'Unrelated ChatGPT app excluded'
    Assert-Test (-not (Test-CasProcess 'codex-windows-sandbox-service' ($pkg+'\app\resources\codex-windows-sandbox-service.exe') $pkg '')) 'Persistent sandbox service excluded'
    Assert-Test (-not (Test-CasProcess 'ChatGPT' '' $pkg '')) 'Unreadable path is never authorized for termination'
    Assert-Test (Test-CasProcess 'codex' 'C:\Users\A\.vscode\extensions\openai.chatgpt-1\bin\codex.exe' $pkg '') 'VS Code Codex child detected without blocking all VS Code'
    $configBefore=[Convert]::ToBase64String([IO.File]::ReadAllBytes($script:CasConfig))
    $authBefore=[Convert]::ToBase64String([IO.File]::ReadAllBytes($script:CasAuth))
    Backup-CasTransaction
    Write-CasAtomic $script:CasAuth $b
    Write-CasAtomic $script:CasConfig ([Text.Encoding]::UTF8.GetBytes('different config'))
    Restore-CasTransaction
    Assert-Test ([Convert]::ToBase64String([IO.File]::ReadAllBytes($script:CasAuth)) -eq $authBefore) 'Recovery restores exact previous auth bytes'
    Assert-Test ([Convert]::ToBase64String([IO.File]::ReadAllBytes($script:CasConfig)) -eq $configBefore) 'Recovery restores exact previous config bytes'
    Assert-Test (-not (Get-CasStatus).Pending) 'Recovery clears interrupted-transaction marker'
    # Mock only OS app lifecycle. Switching uses real files and transactions.
    $script:FakeRunning=$false
    $script:FakeLaunch='success'
    function Stop-CasDesktop($Installation,[switch]$Force) { $script:FakeRunning=$false }
    function Start-CasDesktop($Installation) {
        if ($script:FakeLaunch -eq 'fail') { throw 'CAS|LAUNCH|Synthetic launch failure' }
        $script:FakeRunning=$true
        if ($script:FakeLaunch -eq 'wrong-account') { Write-CasAtomic $script:CasAuth (New-TestAuth 'eve') }
    }
    function Get-CasProcesses($Installation) { if ($script:FakeRunning) { [pscustomobject]@{Id=123;ProcessName='fake-codex';MainWindowHandle=[IntPtr]::new(1)} } }
    function Wait-Cas([int]$Milliseconds) { }
    $fakeInstall=[pscustomobject]@{Root='fake';Aumid='fake!App';Cli=(Join-Path $testRoot 'fake.exe')}
    [IO.File]::WriteAllBytes($fakeInstall.Cli,[byte[]]@(1))
    $selected=Invoke-CasSwitch 2 $fakeInstall
    Assert-Test ($selected.Email -eq 'bob@example.test' -and (Get-CasAccount (Read-CasLive)).Id -eq (Get-CasAccount $b).Id) 'Full switch commits selected local identity'
    Assert-Test (-not (Get-CasStatus).Pending) 'Successful switch clears pending marker'
    $script:FakeLaunch='fail'
    Assert-Throws { Invoke-CasSwitch 1 $fakeInstall } 'LAUNCH' 'Launch failure reported'
    Assert-Test ((Get-CasAccount (Read-CasLive)).Email -eq 'bob@example.test') 'Launch failure automatically rolls back auth'
    $script:FakeLaunch='wrong-account'
    Assert-Throws { Invoke-CasSwitch 1 $fakeInstall } 'VERIFY' 'Unexpected post-launch identity rejected'
    Assert-Test ((Get-CasAccount (Read-CasLive)).Email -eq 'bob@example.test') 'Identity verification failure rolls back'
    Write-CasAtomic (Join-Path $script:CasVault 'pending') ([byte[]]@(1))
    Assert-Throws { Invoke-CasSwitch 1 $fakeInstall } 'PENDING' 'Interrupted transaction must recover before a new switch'
    Restore-CasTransaction
    # Isolated login should never rewrite the active home.
    $beforeLogin=[Convert]::ToBase64String([IO.File]::ReadAllBytes($script:CasAuth))
    function Start-CasLoginProcess([string]$Cli,[string]$LoginHome,[switch]$DeviceCode) {
        Assert-Test ($LoginHome -ne $script:CasHome -and $LoginHome.StartsWith($script:CasVault)) 'Sign-in uses isolated private home'
        Write-CasAtomic (Join-Path $LoginHome 'auth.json') (New-TestAuth 'alice' 'fresh-isolated')
        $p=[pscustomobject]@{HasExited=$true;ExitCode=0}
        $p | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { }
        $p | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
        return $p
    }
    $signedIn=Add-CasLogin 1 $fakeInstall
    Assert-Test ($signedIn.Email -eq 'alice@example.test') 'Isolated official-login result saved into correct slot'
    Assert-Test ([Convert]::ToBase64String([IO.File]::ReadAllBytes($script:CasAuth)) -eq $beforeLogin) 'Adding account leaves active auth unchanged'
    Assert-Test (@(Get-ChildItem -LiteralPath $script:CasVault -Directory -Filter 'login-*').Count -eq 0) 'Temporary sign-in credentials cleaned up'
    Write-Host ''
    Write-Host ("All $script:Passed checks passed. No real account or desktop app was used.") -ForegroundColor Cyan
    if ($env:OS -eq 'Windows_NT') { Write-Host 'Windows DPAPI and private folder permissions were exercised.' }
} finally {
    Close-Cas
    if ([IO.Directory]::Exists($testRoot)) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
