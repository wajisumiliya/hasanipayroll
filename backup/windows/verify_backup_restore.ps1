$ErrorActionPreference = "Stop"

param(
  [Parameter(Mandatory=$true)]
  [string]$BackupZip
)

# Safety rule: this verifier restores ONLY into a temporary PostgreSQL database
# on localhost. It never accepts or uses the production Supabase database URL.
$PgRestore = Get-Command pg_restore -ErrorAction SilentlyContinue
$Psql = Get-Command psql -ErrorAction SilentlyContinue
$Createdb = Get-Command createdb -ErrorAction SilentlyContinue
$Dropdb = Get-Command dropdb -ErrorAction SilentlyContinue
if (-not $PgRestore -or -not $Psql -or -not $Createdb -or -not $Dropdb) {
  throw "PostgreSQL client tools (pg_restore, psql, createdb, dropdb) must be installed and in PATH."
}

if (-not (Test-Path $BackupZip)) { throw "Backup ZIP not found: $BackupZip" }

$TempRoot = Join-Path ([IO.Path]::GetTempPath()) ("hasani_restore_" + [guid]::NewGuid().ToString("N"))
$DbName = "hasani_restore_" + (Get-Date -Format "yyyyMMddHHmmss") + "_" + (Get-Random -Maximum 9999)
New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

try {
  Write-Host "1/5 Extracting backup..."
  Expand-Archive -Path $BackupZip -DestinationPath $TempRoot -Force

  $Dump = Get-ChildItem $TempRoot -Recurse -File -Filter "database.dump" | Select-Object -First 1
  $HashFile = Get-ChildItem $TempRoot -Recurse -File -Filter "SHA256SUMS.txt" | Select-Object -First 1
  if (-not $Dump) { throw "database.dump was not found in the backup ZIP." }
  if (-not $HashFile) { throw "SHA256SUMS.txt was not found in the backup ZIP." }

  Write-Host "2/5 Verifying SHA-256 checksums..."
  $Base = $HashFile.Directory.FullName
  foreach ($Line in Get-Content $HashFile.FullName) {
    if ([string]::IsNullOrWhiteSpace($Line)) { continue }
    if ($Line -notmatch '^([A-Fa-f0-9]{64})\s{2}(.+)$') { throw "Invalid checksum line: $Line" }
    $Expected = $Matches[1].ToUpperInvariant()
    $Relative = $Matches[2]
    $File = Join-Path $Base $Relative
    if (-not (Test-Path $File)) { throw "Backup file missing: $Relative" }
    $Actual = (Get-FileHash $File -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($Actual -ne $Expected) { throw "Checksum mismatch: $Relative" }
  }

  $HostName = if ($env:HASANI_RESTORE_HOST) { $env:HASANI_RESTORE_HOST } else { "localhost" }
  if ($HostName -notin @("localhost","127.0.0.1","::1")) {
    throw "Safety stop: restore host must be localhost/loopback. Refusing host '$HostName'."
  }
  $Port = if ($env:HASANI_RESTORE_PORT) { $env:HASANI_RESTORE_PORT } else { "5432" }
  $User = if ($env:HASANI_RESTORE_USER) { $env:HASANI_RESTORE_USER } else { "postgres" }

  Write-Host "3/5 Creating temporary local database $DbName..."
  & $Createdb.Source "-h" $HostName "-p" $Port "-U" $User $DbName
  if ($LASTEXITCODE -ne 0) { throw "Could not create temporary local restore database." }

  Write-Host "4/5 Restoring database dump..."
  & $PgRestore.Source "-h" $HostName "-p" $Port "-U" $User "-d" $DbName "--no-owner" "--no-acl" "--exit-on-error" $Dump.FullName
  if ($LASTEXITCODE -ne 0) { throw "pg_restore failed." }

  Write-Host "5/5 Running restore sanity checks..."
  $Sql = @"
select case when count(*) >= 3 then 'PASS' else 'FAIL' end
from information_schema.tables
where table_schema='public'
  and table_name in ('employees','attendance','payroll');
"@
  $Result = (& $Psql.Source "-h" $HostName "-p" $Port "-U" $User "-d" $DbName "-X" "-A" "-t" "-v" "ON_ERROR_STOP=1" "-c" $Sql).Trim()
  if ($LASTEXITCODE -ne 0 -or $Result -ne "PASS") {
    throw "Restore sanity check failed. Expected employees, attendance and payroll tables."
  }

  Write-Host ""
  Write-Host "BACKUP RESTORE VERIFICATION: PASS" -ForegroundColor Green
  Write-Host "Checksums are valid and the PostgreSQL dump restored successfully into an isolated local database."
}
finally {
  if ($DbName) {
    & $Dropdb.Source "-h" "localhost" "-p" $(if ($env:HASANI_RESTORE_PORT) {$env:HASANI_RESTORE_PORT} else {"5432"}) "-U" $(if ($env:HASANI_RESTORE_USER) {$env:HASANI_RESTORE_USER} else {"postgres"}) "--if-exists" $DbName 2>$null
  }
  if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }
}
