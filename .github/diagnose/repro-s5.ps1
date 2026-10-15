param([string]$Fixtures)
$ErrorActionPreference = 'Stop'
function New-Fixture {
  $base = Join-Path $env:TEMP ("repro-s5-" + [guid]::NewGuid())
  $b = Join-Path $base 'alpha\materialized\B'
  $d = Join-Path $base 'beta\elsewhere\D'
  $e = Join-Path $base 'consumer\E'
  New-Item -ItemType Directory -Force $b, $d, $e | Out-Null
  Copy-Item -Recurse "$Fixtures\root-one\B\*" $b
  Copy-Item -Recurse "$Fixtures\root-two\D\*" $d
  Copy-Item -Recurse "$Fixtures\E\Sources" $e
  $template = Get-Content -Raw "$Fixtures\E\Package.template.swift"
  $manifest = $template.Replace('PATH_B', '/' + ($b -replace '\\', '/')).Replace('PATH_D', '/' + ($d -replace '\\', '/'))
  Set-Content -NoNewline -Path (Join-Path $e 'Package.swift') -Value $manifest
  return $e
}
function Invoke-Build([string]$label, [string]$cwd, [bool]$pipes) {
  "===== $label cwd=$cwd pipes=$pipes"
  Get-Content (Join-Path ($cwd -replace '^\\\\\?\\', '') 'Package.swift')
  $psi = [System.Diagnostics.ProcessStartInfo]::new('swift', 'build -j 4')
  $psi.WorkingDirectory = $cwd
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $pipes
  $psi.RedirectStandardError = $pipes
  $started = Get-Date
  $p = [System.Diagnostics.Process]::Start($psi)
  if ($pipes) { $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync() }
  $done = $p.WaitForExit(300000)
  $seconds = [int]((Get-Date) - $started).TotalSeconds
  if ($done) { "----- $label exited $($p.ExitCode) after ${seconds}s" }
  else {
    "----- $label TIMEOUT after ${seconds}s; live processes:"
    Get-CimInstance Win32_Process | Where-Object { $_.CreationDate -ge $started } |
      Select-Object ProcessId, ParentProcessId, Name, ThreadCount, CommandLine | Format-Table -AutoSize | Out-String -Width 400
    & taskkill /T /F /PID $p.Id
  }
  if ($pipes) {
    if ($o.Wait(20000)) { "stdout:"; $o.Result } else { "stdout: (still open)" }
    if ($e.Wait(20000)) { "stderr:"; $e.Result } else { "stderr: (still open)" }
  }
}
swift --version
Invoke-Build 'plain-cwd-pipes' (New-Fixture) $true
Invoke-Build 'verbatim-cwd-pipes' ('\\?\' + (New-Fixture)) $true
Invoke-Build 'verbatim-cwd-inherit' ('\\?\' + (New-Fixture)) $false
Invoke-Build 'plain-cwd-inherit' (New-Fixture) $false
