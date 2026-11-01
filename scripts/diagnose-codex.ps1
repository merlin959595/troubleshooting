# Read-only diagnostic / 只读诊断
$pkg = Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue
$pkg | Select-Object Name,Version,Status,InstallLocation
if ($pkg) {
 $exe=Join-Path $pkg.InstallLocation 'app\resources\codex.exe'
 Write-Host 'CLI exists:' (Test-Path -LiteralPath $exe -PathType Leaf)
 if (Test-Path -LiteralPath $exe -PathType Leaf) { & $exe --version }
}
'User','Machine','Process' | ForEach-Object {
 [PSCustomObject]@{ Scope=$_; Value=[Environment]::GetEnvironmentVariable('CODEX_CLI_PATH',$_) }
} | Format-Table -AutoSize
$cfg=Join-Path $env:USERPROFILE '.codex\config.toml'
if (Test-Path -LiteralPath $cfg) {
 Select-String -LiteralPath $cfg -Pattern '^\s*(notify|integratedTerminalShell|global|runCodexInWindowsSubsystemForLinux|CODEX_CLI_PATH)\s*=' | ForEach-Object {
  [PSCustomObject]@{Line=$_.LineNumber; Key=([regex]::Match($_.Line,'^\s*([\w-]+)\s*=')).Groups[1].Value}
 }
}
$root=Join-Path $env:LOCALAPPDATA 'Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs'
if(Test-Path -LiteralPath $root){
 Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 5 | ForEach-Object {
  $matches=@(Select-String -LiteralPath $_.FullName -Pattern 'Desktop startup policy read failed|rename_staging|EPERM' -ErrorAction SilentlyContinue)
  [PSCustomObject]@{Log=$_.Name; ErrorMatches=$matches.Count}
 }
}
Write-Host 'Done. Review privacy before sharing results / 结束，请保护隐私'
