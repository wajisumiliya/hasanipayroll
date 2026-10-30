param(
    [switch]$Quick
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

function Invoke-LocalCheckStep {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Host "`n==> $Name" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

Write-Host 'Hasani Payroll local verification' -ForegroundColor Green
Write-Host "Mode: $(if ($Quick) { 'quick pre-push checks' } else { 'full CI-style checks' })"

Invoke-LocalCheckStep 'Resolve locked Flutter dependencies' {
    flutter pub get --enforce-lockfile
}

Invoke-LocalCheckStep 'Check Dart formatting (does not modify files)' {
    dart format --output=none --set-exit-if-changed lib test
}

Invoke-LocalCheckStep 'Analyze Flutter source' {
    flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos
}

Invoke-LocalCheckStep 'Run Flutter tests' {
    flutter test --no-pub
}

if (-not $Quick) {
    Invoke-LocalCheckStep 'Install locked backend dependencies' {
        npm ci --prefix backend
    }

    Invoke-LocalCheckStep 'Run backend tests' {
        npm test --prefix backend
    }

    Invoke-LocalCheckStep 'Compile release Flutter web preview' {
        flutter build web --release --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:5001
    }

    $webEntry = Join-Path $projectRoot 'build\web\index.html'
    if (-not (Test-Path -LiteralPath $webEntry)) {
        throw "Web build completed without producing $webEntry."
    }
}

Write-Host "`nAll local checks passed." -ForegroundColor Green
if ($Quick) {
    Write-Host 'Run npm run check for backend tests and a release web compilation.'
} else {
    Write-Host 'The release web preview is available in build\web.'
}
