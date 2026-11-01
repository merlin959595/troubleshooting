# Restore backed-up config / 恢复备份
[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][string]$BackupPath)
$ErrorActionPreference='Stop'
$source=(Resolve-Path -LiteralPath $BackupPath).Path
if(-not (Test-Path -LiteralPath $source -PathType Leaf)){throw 'Backup missing'}
$target=Join-Path $env:USERPROFILE '.codex\config.toml'
if($PSCmdlet.ShouldProcess($target,"Restore $source")){
 $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
 if(Test-Path -LiteralPath $target -PathType Leaf){Copy-Item -LiteralPath $target -Destination "$target.before-restore-$stamp" -ErrorAction Stop}
 Copy-Item -LiteralPath $source -Destination $target -Force -ErrorAction Stop
 Write-Host 'Restored. Restart Codex / 已恢复，请重启 Codex'
}
