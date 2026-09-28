$ErrorActionPreference = "Stop"
$ProjectRef = "qychfoxygqzmtsqtxihp"
$Bucket = "employee-photos"
$Config = Join-Path $PSScriptRoot "backup_config.local.ps1"
$BackupRoot = Join-Path $PSScriptRoot "HasaniPayroll_Backups"

if (-not (Test-Path $Config)) {
  $template = @'
# LOCAL ONLY. NEVER COMMIT THIS FILE.
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

$PgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
if (-not $PgDump) { throw "pg_dump is not installed or is not in PATH. Install PostgreSQL client tools first." }

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
