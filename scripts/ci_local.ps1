# Local CI simulator for cj-memo (PowerShell)
# Run from project root:
#   powershell -ExecutionPolicy Bypass -File scripts/ci_local.ps1

$ErrorActionPreference = "Stop"
$ProjRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $ProjRoot

$Log = Join-Path $ProjRoot "ci_run.log"
"" | Out-File -FilePath $Log -Encoding utf8

function Step($n, $title) {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "STEP $n/6: $title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Add-Content -Path $Log -Value ""
    Add-Content -Path $Log -Value "============================================================"
    Add-Content -Path $Log -Value "STEP $n/6: $title"
    Add-Content -Path $Log -Value "============================================================"
}

function Run($cmd) {
    Write-Host $cmd -ForegroundColor Gray
    Add-Content -Path $Log -Value ""
    Add-Content -Path $Log -Value ">>> $cmd"
    cmd.exe /c $cmd 2>&1 | Tee-Object -FilePath $Log -Append | Out-Host
}

# Step 1: detect cjc
Step "1" "Check Cangjie SDK"
$cjc = (Get-Command cjc -ErrorAction SilentlyContinue)
if ($cjc) {
    Write-Host "[OK] cjc detected: $($cjc.Source)" -ForegroundColor Green
    Add-Content -Path $Log -Value "[OK] cjc detected: $($cjc.Source)"
    Run "cjc --version"
} else {
    Write-Host "[FAIL] cjc not found. Install Cangjie SDK first." -ForegroundColor Red
    Add-Content -Path $Log -Value "[FAIL] cjc not found"
    exit 1
}

# Step 2: build
Step "2" "cjpm build"
Run "cd /d $ProjRoot && cjpm build"

# Step 3: test
Step "3" "cjpm test"
$testOut = Join-Path $ProjRoot "test_output.txt"
Run "cd /d $ProjRoot && cjpm test > test_output.txt 2>&1"

# Step 4: parse test result
Step "4" "Parse test result"
$testLog = Get-Content $testOut -Raw
$testsPassed = ($testLog -match "PASSED: 19,.*FAILED: 0")
$testsFailed = ($testLog -match "FAILED: [1-9]")

if ($testsPassed -and -not $testsFailed) {
    Write-Host "[OK] 19 / 19 test cases passed" -ForegroundColor Green
    Add-Content -Path $Log -Value "[OK] 19 / 19 test cases passed"
    $testOk = $true
} else {
    Write-Host "[FAIL] Some tests failed, see test_output.txt" -ForegroundColor Red
    Add-Content -Path $Log -Value "[FAIL] Some tests failed"
    $testOk = $false
}

# Step 5: SHA-256 standard vectors
Step "5" "SHA-256 standard vectors"
$EMPTY_EXP = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
$ABC_EXP   = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
$LONG_EXP  = "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592"

$empty_act = ([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes("")) | ForEach-Object { $_.ToString("x2") }) -join ""
$abc_act   = ([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes("abc")) | ForEach-Object { $_.ToString("x2") }) -join ""
$long_act  = ([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes("The quick brown fox jumps over the lazy dog")) | ForEach-Object { $_.ToString("x2") }) -join ""

Add-Content -Path $Log -Value "empty   expected: $EMPTY_EXP"
Add-Content -Path $Log -Value "        actual:   $empty_act"
Add-Content -Path $Log -Value "abc     expected: $ABC_EXP"
Add-Content -Path $Log -Value "        actual:   $abc_act"
Add-Content -Path $Log -Value "long    expected: $LONG_EXP"
Add-Content -Path $Log -Value "        actual:   $long_act"

Write-Host "empty   expected: $EMPTY_EXP"
Write-Host "        actual:   $empty_act"
Write-Host "abc     expected: $ABC_EXP"
Write-Host "        actual:   $abc_act"
Write-Host "long    expected: $LONG_EXP"
Write-Host "        actual:   $long_act"

if ($empty_act -eq $EMPTY_EXP -and $abc_act -eq $ABC_EXP -and $long_act -eq $LONG_EXP) {
    Write-Host "[OK] SHA-256 vectors all matched" -ForegroundColor Green
    Add-Content -Path $Log -Value "[OK] SHA-256 vectors all matched"
    $shaOk = $true
} else {
    Write-Host "[FAIL] SHA-256 vectors mismatch" -ForegroundColor Red
    Add-Content -Path $Log -Value "[FAIL] SHA-256 vectors mismatch"
    $shaOk = $false
}

# Step 6: summary
Step "6" "Summary"
Write-Host "build: [OK]" -ForegroundColor Green
Write-Host ("test:  " + (if ($testOk) { "[OK] (19/19)" } else { "[FAIL]" })) -ForegroundColor $(if ($testOk) { "Green" } else { "Red" })
Write-Host ("hash:  " + (if ($shaOk)  { "[OK]" } else { "[FAIL]" })) -ForegroundColor $(if ($shaOk)  { "Green" } else { "Red" })

Add-Content -Path $Log -Value ""
Add-Content -Path $Log -Value "===== Summary ====="
Add-Content -Path $Log -Value "build: [OK]"
Add-Content -Path $Log -Value ("test:  " + (if ($testOk) { "[OK] (19/19)" } else { "[FAIL]" }))
Add-Content -Path $Log -Value ("hash:  " + (if ($shaOk)  { "[OK]" } else { "[FAIL]" }))
Add-Content -Path $Log -Value ""
Add-Content -Path $Log -Value "Log saved to: $Log"

Write-Host ""
Write-Host "Full log: $Log" -ForegroundColor Cyan

if ($testOk -and $shaOk) {
    Write-Host ""
    Write-Host "[SUCCESS] Local CI simulation passed (equivalent to GitHub Actions green build)" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "[FAIL] Some checks failed, see log above" -ForegroundColor Red
    exit 1
}