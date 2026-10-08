$ErrorActionPreference='Stop'
$taskBatch='C:/Users/yasmo/EchoNetwork/artifacts/eleven-eleven/art/production/tripo-20261007'
$taskLock=[IO.File]::Open($taskBatch+'/ledger.lock',[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
 $taskLedger=Get-Content -LiteralPath ($taskBatch+'/spending-ledger.json') -Raw | ConvertFrom-Json
 $taskSnapshot=$taskBatch+'/spending-ledger-before-reconcile-20261008.json'
 if (-not (Test-Path -LiteralPath $taskSnapshot)) { Copy-Item -LiteralPath ($taskBatch+'/spending-ledger.json') -Destination $taskSnapshot }
 $taskOrigin=$taskLedger.entries | Where-Object jobId -eq 'zero-rig-v1'
 $taskOrigin.actualCredits=25
 $taskOrigin | Add-Member -NotePropertyName taskId -NotePropertyValue '925ca3b6-75b7-42f1-81ff-cf6119ed4c81' -Force
 foreach($taskFree in @('zero-rig-inspect','zero-motion-inspect')) {
   $taskEntry=$taskLedger.entries | Where-Object jobId -eq $taskFree
   $taskEntry.actualCredits=0
   $taskEntry | Add-Member -NotePropertyName accountingNote -NotePropertyValue 'Read-only inspection: source task credits are not a new charge' -Force
 }
 foreach($taskFailed in @('zero-motion-v1','zero-idle-v2','zero-idle-legacy-v3')) {
   $taskEntry=$taskLedger.entries | Where-Object jobId -eq $taskFailed
   $taskProof=Get-Content -LiteralPath $taskEntry.resultFile -Raw | ConvertFrom-Json
   if ($taskProof.error -notlike '*frozen credits have been refunded automatically*') { throw 'Refund proof missing' }
   $taskEntry.actualCredits=0
   $taskEntry.status='failed_refunded'
   $taskEntry | Add-Member -NotePropertyName accountingNote -NotePropertyValue 'CLI failure explicitly confirmed automatic refund; original attempt preserved' -Force
 }
 $taskBalance=Get-Content -LiteralPath ($taskBatch+'/balance-20261008-v2-result.json') -Raw | ConvertFrom-Json
 $taskSpend=($taskLedger.entries | Measure-Object -Property actualCredits -Sum).Sum
 if ($taskBalance.frozen -ne 0 -or (600-$taskBalance.balance) -ne $taskSpend) { throw 'Actual charge reconciliation does not match account balance' }
 $taskLedger | Add-Member -NotePropertyName reconciliation -NotePropertyValue ([pscustomobject]@{verifiedAt=[DateTime]::UtcNow.ToString('o');actualSpent=$taskSpend;balance=$taskBalance.balance;frozen=$taskBalance.frozen;proof='balance-20261008-v2-result.json';scope='Source task charges deduplicated; free inspections0; failed retarget refunds0'}) -Force
 $taskLedger | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath ($taskBatch+'/spending-ledger.json') -Encoding utf8
 Write-Output ('Verified actualSpent='+$taskSpend+' balance='+$taskBalance.balance+' frozen='+$taskBalance.frozen)
} finally { $taskLock.Dispose() }
