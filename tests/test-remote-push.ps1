# Mock tests for the remote push policy and config (lib/remote.ps1, T16/D22). Fixture data only;
# no network except a refused connection to 127.0.0.1. Not a live game test.
# Run: pwsh -NoProfile -File tests/test-remote-push.ps1   (Windows: powershell.exe -File ...)
$ErrorActionPreference='Stop'
try { Remove-TypeData System.Array -ErrorAction Stop } catch { }
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'lib/common.ps1')
. (Join-Path $root 'lib/remote.ps1')
function Check($condition,$label) { if (!$condition) { throw "FAIL $label" }; Write-Host "PASS $label" }
$utf8=New-Object Text.UTF8Encoding($false)
$tmpBase=if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$tmp=Join-Path $tmpBase ('lcb-remote-'+[guid]::NewGuid())
$null=New-Item -ItemType Directory $tmp

function Snap([int]$level=22,[string]$subzone='SubA',[double]$x=50.0,[double]$y=30.0,[int]$have=9,[int]$weapon=6505) {
  [pscustomobject]@{schemaVersion=1;capturedAt=1000;session='1-1';sequence=1;status='snapshot_received'
    character=[pscustomobject]@{name='Test';level=$level}
    location=[pscustomobject]@{zone='ZoneA';subzone=$subzone;mapID=1413;x=$x;y=$y}
    quests=@([pscustomobject]@{id=123;name='Q';complete=$false;objectives=@([pscustomobject]@{text="$have/20";numFulfilled=$have;numRequired=20})})
    equipment=@([pscustomobject]@{slot=16;id=$weapon;name='Staff'})}
}

# ---------- Push policy ----------
$st=New-PushState
Check ((Get-PushDecision $st ([pscustomobject]@{status='waiting_for_game'}) 0) -eq 'none') 'no character: nothing to push'
Check ((Get-PushDecision $st (Snap) 0) -eq 'first') 'first snapshot is pushed at once'
Set-PushDone $st (Snap) 0
Check ((Get-PushDecision $st (Snap) 10) -eq 'none') 'unchanged within 3 min: no push'
Check ((Get-PushDecision $st (Snap) 179) -eq 'none') 'unchanged at 179 s: no push'
Check ((Get-PushDecision $st (Snap) 180) -eq 'heartbeat') 'unchanged at 180 s: heartbeat'
# A new capturedAt alone (addon re-sends every 15 s) is not a change.
$same=Snap; $same.capturedAt=2000; $same.sequence=99
Check ((Get-PushDecision $st $same 60) -eq 'none') 'new capturedAt/sequence alone is not a change'
Check ((Get-PushDecision $st (Snap -level 23) 29) -eq 'none') 'level change inside 30 s waits'
Check ((Get-PushDecision $st (Snap -level 23) 30) -eq 'change') 'level change pushed once 30 s passed'
Check ((Get-PushDecision $st (Snap -subzone 'SubB') 45) -eq 'change') 'subzone change'
Check ((Get-PushDecision $st (Snap -have 10) 45) -eq 'change') 'quest progress change'
Check ((Get-PushDecision $st (Snap -weapon 7000) 45) -eq 'change') 'equipment change'
$noQuest=Snap; $noQuest.quests=@()
Check ((Get-PushDecision $st $noQuest 45) -eq 'change') 'quest removed'
Check ((Get-PushDecision $st (Snap -x 52.0 -y 31.0) 45) -eq 'none') 'move of 2.2 map-percent: no push'
Check ((Get-PushDecision $st (Snap -x 52.5 -y 32.0) 45) -eq 'move') 'move of 3.2 map-percent: push'
Check ((Get-PushDecision $st (Snap -x 50.0 -y 33.5) 20) -eq 'none') 'move inside 30 s waits'
$noXY=Snap; $noXY.location.x=$null; $noXY.location.y=$null
Check ((Get-PushDecision $st $noXY 45) -eq 'none') 'missing coordinates do not count as a move'
Set-PushDone $st (Snap -level 23) 100
Check ((Get-PushDecision $st (Snap -level 23) 130) -eq 'none' -and (Get-PushDecision $st (Snap -level 23) 280) -eq 'heartbeat') 'after a push the heartbeat clock restarts'
# Worst case: a change every 2 s (reader loop) for a day stays at most one push per 30 s.
$st2=New-PushState; $n=0
for ($t=0;$t -lt 3600;$t+=2) { $s=Snap -level (1+$t%50); if ((Get-PushDecision $st2 $s $t) -ne 'none') { Set-PushDone $st2 $s $t; $n++ } }
Check ($n -le 121) "constant changes for 1 h: $n pushes (at most one per 30 s)"
$st3=New-PushState; $n=0
for ($t=0;$t -lt 3600;$t+=2) { if ((Get-PushDecision $st3 (Snap) $t) -ne 'none') { Set-PushDone $st3 (Snap) $t; $n++ } }
Check ($n -eq 20) "no changes for 1 h: $n pushes (first + heartbeat every 3 min)"

# ---------- Backoff ----------
$st=New-PushState
Set-PushFailed $st 0 'x'; Check ($st.nextAttemptAt -eq 30 -and (Get-PushDecision $st (Snap) 29) -eq 'none' -and (Get-PushDecision $st (Snap) 30) -eq 'first') 'failure waits 30 s before retrying'
Set-PushFailed $st 30 'x'; Check ($st.nextAttemptAt -eq 90) 'second failure waits 60 s'
for ($i=0;$i -lt 10;$i++) { Set-PushFailed $st 1000 'x' }
Check ($st.nextAttemptAt -eq 1300) 'backoff capped at 5 min'

# ---------- Config ----------
$cfg=Join-Path $tmp 'remote.json'
Check ($null -eq (Read-RemoteConfig $cfg)) 'no config file: upload off (default)'
$good='abcdefghijklmnopqrstuvwxyz0123456789'
function Write-Cfg($o) { [IO.File]::WriteAllText($cfg,($o | ConvertTo-Json),$utf8) }
Write-Cfg @{enabled=$false;url='https://example.invalid';uploadToken=$good}
Check ($null -eq (Read-RemoteConfig $cfg)) 'enabled=false: upload off'
Write-Cfg @{enabled=$true;url='http://example.invalid';uploadToken=$good}
$threw=$false; try { $null=Read-RemoteConfig $cfg } catch { $threw=$_.Exception.Message -match 'https' }
Check $threw 'plain http to another host is refused'
Write-Cfg @{enabled=$true;url='https://example.invalid';uploadToken='short'}
$threw=$false; try { $null=Read-RemoteConfig $cfg } catch { $threw=$true }
Check $threw 'short upload token is refused'
Write-Cfg @{enabled=$true;url='https://example.invalid/';uploadToken=$good}
$c=Read-RemoteConfig $cfg
Check ($c -and (Get-RemoteEndpoint $c '/upload') -eq 'https://example.invalid/upload') 'valid config enables upload'
$env:WOW_CONTEXT_REMOTE_CONFIG=$cfg
Check ((Get-RemoteConfigPath) -eq $cfg) 'WOW_CONTEXT_REMOTE_CONFIG overrides the config path'
Remove-Item Env:WOW_CONTEXT_REMOTE_CONFIG
$default=Get-RemoteConfigPath
Check (!$default.StartsWith($root) -and $default.EndsWith('remote.json')) "default config is outside the repository ($(Split-Path -Leaf (Split-Path -Parent $default))/remote.json)"

# ---------- Upload body ----------
$hist=Join-Path $tmp 'history.jsonl'
$lines=@(); for ($i=1;$i -le 60;$i++) { $lines+=(@{capturedAt=$i;location=@{zone='ZoneA'};changes=@("level $i");digest=@{name='Test'}} | ConvertTo-Json -Compress -Depth 5) }
[IO.File]::WriteAllText($hist,($lines -join "`n")+"`n",$utf8)
$body=Get-UploadBody (Snap) $hist | ConvertFrom-Json
Check ($body.snapshot.character.name -eq 'Test' -and @($body.history).Count -eq 50 -and $body.history[0].capturedAt -eq 11) 'body has the snapshot and the last 50 history entries'
Check (!((Get-UploadBody (Snap) $hist).Contains('digest'))) 'internal history digest is not uploaded'
$one=Get-UploadBody (Snap) (Join-Path $tmp 'missing.jsonl') | ConvertFrom-Json
Check (@($one.history).Count -eq 0) 'missing history file uploads an empty list'

# ---------- Failure handling ----------
$down=[pscustomobject]@{enabled=$true;url='http://127.0.0.1:9';uploadToken=$good}
$st=New-PushState
$r=Invoke-RemotePushStep $st $down (Snap) $hist 0 3>$null
Check ($r -eq '' -and $st.failures -eq 1 -and $st.nextAttemptAt -eq 30 -and $null -eq $st.lastPushAt) 'unreachable server: no crash, retry later'

Remove-Item -LiteralPath $tmp -Recurse -Force
Write-Host 'Mock tests only; not a live game or Cloudflare test.'
