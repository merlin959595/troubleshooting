# Backup-first targeted workaround / 先备份的精准修复
[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$SourcePath)
$ErrorActionPreference='Stop'
$dir=Join-Path $env:USERPROFILE '.codex'
$target=Join-Path $dir 'config.toml'
if(-not $SourcePath){
 if(Test-Path -LiteralPath $target -PathType Leaf){$SourcePath=$target}
 else{
  $old=Get-ChildItem -LiteralPath $dir -Filter 'config.toml.disabled-*' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if(-not $old){throw 'No config found / 找不到配置'}
  $SourcePath=$old.FullName
 }
}
if(-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)){throw 'Source missing'}
$raw=[IO.File]::ReadAllText($SourcePath)
$lines=$raw -split '\r?\n'
$count=0
$fixed=foreach($line in $lines){
 if($line -match '^[ \t]*notify[ \t]*=\s*\[[^\r\n]*\]\s*$' -or
 $line -match '^[ \t]*integratedTerminalShell[ \t]*=\s*["'']wsl["'']\s*$' -or
 $line -match '^[ \t]*global[ \t]*=\s*["'']wsl["'']\s*$' -or
 $line -match '^[ \t]*runCodexInWindowsSubsystemForLinux[ \t]*=\s*true\s*$'){
  $count++; '# TEMP DISABLED: '+$line
 } else {$line}
}
Write-Host "Matched settings / 命中配置: $count"
if($count -eq 0){throw 'No expected settings matched; no changes / 未找到匹配项'}
if($PSCmdlet.ShouldProcess($target,'Backup and write adjusted config / 备份并修复配置')){
 $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
 if(Test-Path -LiteralPath $target -PathType Leaf){Copy-Item -LiteralPath $target -Destination "$target.before-fix-$stamp" -ErrorAction Stop}
 Copy-Item -LiteralPath $SourcePath -Destination "$target.source-backup-$stamp" -ErrorAction Stop
 $utf8=New-Object Text.UTF8Encoding($false)
 [IO.File]::WriteAllText($target,($fixed -join [Environment]::NewLine),$utf8)
 Write-Host 'Done; restart Codex / 已完成，请重启 Codex'
}
