$ErrorActionPreference = "Stop"
$ProjectRef = "qychfoxygqzmtsqtxihp"
$Bucket = "employee-photos"
$Config = Join-Path $PSScriptRoot "backup_config.local.ps1"
$BackupRoot = Join-Path $PSScriptRoot "HasaniPayroll_Backups"

if (-not (Test-Path $Config)) {
  $template = @'
# LOCAL ONLY. NEVER COMMIT THIS FILE.
# Copy the Session Pooler database URL exactly from Supabase Dashboard -> Connect.
$env:HASANI_SUPABASE_DB_URL = "PASTE_SESSION_POOLER_DATABASE_URL_HERE"
$env:HASANI_SUPABASE_SERVICE_ROLE_KEY = "PASTE_SERVICE_ROLE_KEY_HERE"
'@
  Set-Content -Path $Config -Value $template -Encoding UTF8
  Write-Host "Created backup_config.local.ps1" -ForegroundColor Yellow
  Write-Host "Open that file, paste your Supabase Session Pooler database URL and service_role key, save it, then run BACKUP_HASANI_PAYROLL.bat again."
  exit 2
}

. $Config
if (-not $env:HASANI_SUPABASE_DB_URL -or $env:HASANI_SUPABASE_DB_URL -like "*PASTE_*") { throw "Database URL is not configured." }
if (-not $env:HASANI_SUPABASE_SERVICE_ROLE_KEY -or $env:HASANI_SUPABASE_SERVICE_ROLE_KEY -like "*PASTE_*") { throw "Service role key is not configured." }

try {
  $DbUri = [uri]$env:HASANI_SUPABASE_DB_URL
} catch {
  throw "Database URL is invalid. Copy the complete Session Pooler database URL from Supabase Dashboard -> Connect."
}

if ($DbUri.Scheme -notin @("postgres", "postgresql")) {
  throw "Database URL must start with postgres:// or postgresql://."
}
if (-not $DbUri.Host) { throw "Database URL does not contain a database host." }
if ($DbUri.UserInfo -notmatch ":") { throw "Database URL must include both database username and password." }

$DbUser = ($DbUri.UserInfo -split ":", 2)[0]
if ($DbUri.Host -like "*.pooler.supabase.com" -and $DbUser -eq "postgres") {
  throw "Wrong Supabase pooler username. Do not use plain 'postgres' with the shared pooler. Copy the Session Pooler URL exactly from Supabase Dashboard -> Connect; for this project the pooler username should be project-qualified (postgres.$ProjectRef)."
}

$PgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
if (-not $PgDump) { throw "pg_dump is not installed or is not in PATH. Install PostgreSQL client tools first." }

$Psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $Psql) { throw "psql is not installed or is not in PATH. Install PostgreSQL client tools first." }

Write-Host "0/4 Validating PostgreSQL connection..."
& $Psql.Source "--dbname=$($env:HASANI_SUPABASE_DB_URL)" "--no-psqlrc" "--tuples-only" "--no-align" "--command=select 1;" | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Database connection validation failed. Re-copy the Session Pooler URL from Supabase Dashboard -> Connect. If authentication fails, the password in the local URL is not valid. No backup files were created."
}

$Stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$Work = Join-Path $BackupRoot $Stamp
$DbDir = Join-Path $Work "database"
$StorageDir = Join-Path $Work "employee-photos"
New-Item -ItemType Directory -Force -Path $DbDir,$StorageDir | Out-Null

Write-Host "1/4 Backing up PostgreSQL database..."
$Dump = Join-Path $DbDir "database.dump"
$Schema = Join-Path $DbDir "schema.sql"
& $PgDump.Source "--dbname=$($env:HASANI_SUPABASE_DB_URL)" "--format=custom" "--no-owner" "--no-acl" "--file=$Dump"
if ($LASTEXITCODE -ne 0) { throw "Database backup failed." }
& $PgDump.Source "--dbname=$($env:HASANI_SUPABASE_DB_URL)" "--schema-only" "--no-owner" "--no-acl" "--file=$Schema"
if ($LASTEXITCODE -ne 0) { throw "Schema backup failed." }

Write-Host "2/4 Backing up private employee photos..."
$Base = "https://" + $ProjectRef + ".supabase.co"
$Headers = @{ Authorization = "Bearer " + $env:HASANI_SUPABASE_SERVICE_ROLE_KEY; apikey = $env:HASANI_SUPABASE_SERVICE_ROLE_KEY }

function Copy-StorageFolder([string]$Prefix) {
  $Offset = 0
  do {
    $Payload = @{ prefix=$Prefix; limit=1000; offset=$Offset; sortBy=@{column="name";order="asc"} } | ConvertTo-Json -Depth 4
    $Rows = @(Invoke-RestMethod -Method Post -Uri ($Base + "/storage/v1/object/list/" + $Bucket) -Headers $Headers -ContentType "application/json" -Body $Payload)
    foreach ($Row in $Rows) {
      if (-not $Row.name) { continue }
      if ($Prefix) { $ObjectPath = $Prefix + "/" + $Row.name } else { $ObjectPath = $Row.name }
      if ($null -eq $Row.id) { Copy-StorageFolder $ObjectPath; continue }
      $Relative = $ObjectPath -replace "/", [IO.Path]::DirectorySeparatorChar
      $Destination = Join-Path $StorageDir $Relative
      New-Item -ItemType Directory -Force -Path (Split-Path $Destination) | Out-Null
      $Encoded = (($ObjectPath.Split("/") | ForEach-Object { [uri]::EscapeDataString($_) }) -join "/")
      $Uri = $Base + "/storage/v1/object/authenticated/" + $Bucket + "/" + $Encoded
      Invoke-WebRequest -UseBasicParsing -Uri $Uri -Headers $Headers -OutFile $Destination
    }
    $Count = $Rows.Count
    $Offset += $Count
  } while ($Count -eq 1000)
}
Copy-StorageFolder ""

Write-Host "3/4 Creating SHA-256 integrity list..."
$HashFile = Join-Path $Work "SHA256SUMS.txt"
Get-ChildItem $Work -File -Recurse | Where-Object { $_.FullName -ne $HashFile } | ForEach-Object {
  $Hash = Get-FileHash $_.FullName -Algorithm SHA256
  $Relative = $_.FullName.Substring($Work.Length + 1)
  $Hash.Hash + "  " + $Relative
} | Set-Content -Path $HashFile -Encoding UTF8

Write-Host "4/4 Creating ZIP..."
$Zip = $Work + ".zip"
Compress-Archive -Path (Join-Path $Work "*") -DestinationPath $Zip -CompressionLevel Optimal
Remove-Item $Work -Recurse -Force
Write-Host ""
Write-Host "Backup created successfully:" -ForegroundColor Green
Write-Host $Zip
Write-Host "Keep a second copy on a private external drive or private cloud storage."
