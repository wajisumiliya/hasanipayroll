param(
  [Parameter(Mandatory=$true)]
  [string]$BackupZip
)

$ErrorActionPreference = "Stop"

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

  # Supabase RLS policies commonly reference platform roles that do not exist
  # in a stock PostgreSQL installation. Create only missing NOLOGIN compatibility
  # roles on this loopback-only local server so policies can be restored and
  # validated instead of being removed from the restore test.
  $CompatibilityRoles = @("anon", "authenticated", "service_role")
  $CreatedCompatibilityRoles = @()
  foreach ($RoleName in $CompatibilityRoles) {
    $RoleExists = (& $Psql.Source "-h" $HostName "-p" $Port "-U" $User "-d" "postgres" "-X" "-A" "-t" "-v" "ON_ERROR_STOP=1" "-v" "role_name=$RoleName" "-c" "select 1 from pg_roles where rolname = :'role_name';").Trim()
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect local PostgreSQL compatibility roles." }
    if ($RoleExists -ne "1") {
      & $Psql.Source "-h" $HostName "-p" $Port "-U" $User "-d" "postgres" "-X" "-v" "ON_ERROR_STOP=1" "-v" "role_name=$RoleName" "-c" "select format('create role %I nologin', :'role_name') \gexec"
      if ($LASTEXITCODE -ne 0) { throw "Could not create local compatibility role '$RoleName'." }
      $CreatedCompatibilityRoles += $RoleName
    }
  }
  if ($CreatedCompatibilityRoles.Count -gt 0) {
    Write-Host ("Created temporary local Supabase compatibility role(s): " + ($CreatedCompatibilityRoles -join ", "))
  }

  # Supabase backups can contain platform-specific extensions (for example
  # supabase_vault) that are not shipped with stock PostgreSQL. Build a
  # pg_restore TOC list and skip only extension objects that the local server
  # reports as unavailable. Application tables/data remain in the restore.
  $RestoreList = Join-Path $TempRoot "restore.list"
  $RestoreListLines = @(& $PgRestore.Source "-l" $Dump.FullName)
  if ($LASTEXITCODE -ne 0) { throw "Could not inspect pg_restore archive." }

  $AvailableExtensionText = (& $Psql.Source "-h" $HostName "-p" $Port "-U" $User "-d" $DbName "-X" "-A" "-t" "-v" "ON_ERROR_STOP=1" "-c" "select name from pg_available_extensions;")
  if ($LASTEXITCODE -ne 0) { throw "Could not query locally available PostgreSQL extensions." }
  $AvailableExtensions = @{}
  foreach ($ExtensionName in $AvailableExtensionText) {
    $Name = ([string]$ExtensionName).Trim()
    if ($Name) { $AvailableExtensions[$Name] = $true }
  }

  $UnavailableExtensions = @{}
  foreach ($Line in $RestoreListLines) {
    if ($Line -match ';[ ]+[0-9]+[ ]+[0-9]+[ ]+EXTENSION[ ]+-[ ]+([^ ]+)[ ]+') {
      $ExtensionName = $Matches[1]
      if (-not $AvailableExtensions.ContainsKey($ExtensionName)) {
        $UnavailableExtensions[$ExtensionName] = $true
      }
    }
  }

  # Some Supabase-managed extensions own schemas whose table/data entries are
  # separate TOC items. Stock PostgreSQL cannot restore those entries after the
  # extension itself is skipped. Keep this mapping intentionally narrow: only
  # known platform-owned schemas are excluded, never application schemas.
  $UnavailableExtensionSchemas = @{}
  if ($UnavailableExtensions.ContainsKey("supabase_vault")) {
    $UnavailableExtensionSchemas["vault"] = $true
  }

  if ($UnavailableExtensions.Count -gt 0) {
    $Names = ($UnavailableExtensions.Keys | Sort-Object) -join ", "
    Write-Host "Local PostgreSQL does not provide Supabase-managed extension(s): $Names"
    if ($UnavailableExtensionSchemas.Count -gt 0) {
      $SchemaNames = ($UnavailableExtensionSchemas.Keys | Sort-Object) -join ", "
      Write-Host "Skipping extension-owned schema object(s) for local verification: $SchemaNames"
    }
    Write-Host "Application schemas and data remain included in this isolated portability test."
  }

  $FilteredRestoreList = foreach ($Line in $RestoreListLines) {
    $Skip = $false
    foreach ($ExtensionName in $UnavailableExtensions.Keys) {
      $EscapedName = [regex]::Escape($ExtensionName)
      if ($Line -match "EXTENSION[ ]+-[ ]+$EscapedName([ ]|$)" -or
          $Line -match "COMMENT[ ]+-[ ]+EXTENSION[ ]+$EscapedName([ ]|$)") {
        $Skip = $true
        break
      }
    }
    if (-not $Skip) {
      foreach ($SchemaName in $UnavailableExtensionSchemas.Keys) {
        $EscapedSchema = [regex]::Escape($SchemaName)
        # pg_restore list entries place the schema immediately after the object
        # type for schema-qualified objects (TABLE, TABLE DATA, SEQUENCE, etc.).
        if ($Line -match ";[ ]+[0-9]+[ ]+[0-9]+[ ]+[^;]+[ ]+$EscapedSchema[ ]+") {
          $Skip = $true
          break
        }
      }
    }
    if ($Skip -and -not $Line.StartsWith(";")) { ";$Line" } else { $Line }
  }

  # Windows PowerShell 5.1 writes a BOM for -Encoding UTF8. pg_restore treats
  # that BOM as text at the beginning of a TOC list, so write UTF-8 without BOM.
  $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllLines($RestoreList, [string[]]$FilteredRestoreList, $Utf8NoBom)

  & $PgRestore.Source "-h" $HostName "-p" $Port "-U" $User "-d" $DbName "--no-owner" "--no-acl" "--exit-on-error" "-L" $RestoreList $Dump.FullName
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
  $CleanupHost = if ($HostName) { $HostName } else { "localhost" }
  $CleanupPort = if ($Port) { $Port } else { "5432" }
  $CleanupUser = if ($User) { $User } else { "postgres" }

  if ($DbName) {
    try {
      & $Dropdb.Source "-h" $CleanupHost "-p" $CleanupPort "-U" $CleanupUser "--if-exists" $DbName 2>$null
    }
    catch {
      Write-Warning "Could not remove temporary restore database '$DbName'. Remove it manually if it still exists."
    }
  }

  if ($CreatedCompatibilityRoles) {
    foreach ($RoleName in $CreatedCompatibilityRoles) {
      try {
        & $Psql.Source "-h" $CleanupHost "-p" $CleanupPort "-U" $CleanupUser "-d" "postgres" "-X" "-v" "ON_ERROR_STOP=1" "-v" "role_name=$RoleName" "-c" "select format('drop role if exists %I', :'role_name') \gexec" 2>$null
      }
      catch {
        Write-Warning "Could not remove temporary local compatibility role '$RoleName'."
      }
    }
  }

  if (Test-Path $TempRoot) { Remove-Item $TempRoot -Recurse -Force }
}
