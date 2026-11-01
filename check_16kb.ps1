
# Beytei Driver - 16KB ELF Alignment Checker
# Works on Windows PowerShell without Python

$ErrorActionPreference = "Stop"

$project = (Get-Location).Path
$aab = Join-Path $project "build\app\outputs\bundle\release\app-release.aab"
$report = Join-Path $project "16kb_report.txt"

Write-Host ""
Write-Host "===================================="
Write-Host " BEYTEI DRIVER - 16KB CHECKER"
Write-Host "===================================="
Write-Host ""

if (!(Test-Path -LiteralPath $aab)) {
    Write-Host "ERROR: AAB file not found!" -ForegroundColor Red
    Write-Host $aab
    exit 1
}

# Find Android SDK and NDK
$sdkRoots = @(
    $env:ANDROID_HOME
    $env:ANDROID_SDK_ROOT
    (Join-Path $env:LOCALAPPDATA "Android\Sdk")
)

# Read custom Android SDK path, if available
$localProps = Join-Path $project "android\local.properties"

if (Test-Path $localProps) {
    $sdkLine = Get-Content $localProps |
        Where-Object { $_ -match '^sdk\.dir=' } |
        Select-Object -First 1

    if ($sdkLine) {
        $sdkPath = $sdkLine.Substring(8)
        $sdkPath = $sdkPath.Replace('\\', '\')
        $sdkPath = $sdkPath.Replace('\:', ':')
        $sdkRoots += $sdkPath
    }
}

$objdump = $null

foreach ($sdk in ($sdkRoots | Where-Object { $_ } | Select-Object -Unique)) {
    $ndkRoot = Join-Path $sdk "ndk"

    if (!(Test-Path $ndkRoot)) {
        continue
    }

    $ndkVersions = Get-ChildItem $ndkRoot -Directory |
        Sort-Object Name -Descending

    foreach ($ndk in $ndkVersions) {
        $candidate = Join-Path $ndk.FullName `
            "toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-objdump.exe"

        if (Test-Path $candidate) {
            $objdump = $candidate
            break
        }
    }

    if ($objdump) {
        break
    }
}

if (!$objdump) {
    Write-Host "ERROR: llvm-objdump.exe not found." -ForegroundColor Red
    Write-Host "Install Android NDK using Android Studio SDK Manager."
    exit 1
}

Write-Host "NDK Tool:"
Write-Host $objdump
Write-Host ""

# Open Android App Bundle
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::OpenRead($aab)
$tempDir = Join-Path $env:TEMP ("beytei16kb_" + [guid]::NewGuid().ToString("N"))

New-Item -ItemType Directory -Path $tempDir | Out-Null

$results = New-Object System.Collections.Generic.List[string]
$failed = New-Object System.Collections.Generic.List[string]
$passed = 0
$errors = 0
$count = 0

try {
    $libraries = @(
        $zip.Entries | Where-Object {
            $_.FullName -match '(^|/)lib/[^/]+/[^/]+\.so$'
        }
    )

    Write-Host "Native libraries found: $($libraries.Count)"
    Write-Host ""

    foreach ($entry in $libraries) {
        $count++

        $tempFile = Join-Path $tempDir ("library_" + $count + ".so")

        $source = $entry.Open()
        $destination = [System.IO.File]::Create($tempFile)

        try {
            $source.CopyTo($destination)
        }
        finally {
            $source.Dispose()
            $destination.Dispose()
        }

        $output = @(& $objdump -p $tempFile 2>&1)

        $alignments = @()
        $unknown = $false

        foreach ($line in $output) {
            $lineText = [string]$line

            if ($lineText -match '^\s*LOAD\s') {
                if ($lineText -match 'align\s+2\*\*(\d+)') {
                    $alignments += [int]$Matches[1]
                }
                else {
                    $unknown = $true
                }
            }
        }

        $status = "PASS"

        if ($unknown -or $alignments.Count -eq 0 -or
            $LASTEXITCODE -ne 0) {
            $status = "ERROR"
            $errors++
        }
        elseif (@($alignments | Where-Object { $_ -lt 14 }).Count -gt 0) {
            $status = "FAIL"
            $failed.Add($entry.FullName)
        }
        else {
            $passed++
        }

        $alignmentText = ($alignments | ForEach-Object {
            "2**$_"
        }) -join ", "

        $result = "$status | $($entry.FullName) | $alignmentText"
        $results.Add($result)

        if ($status -eq "PASS") {
            Write-Host $result -ForegroundColor Green
        }
        elseif ($status -eq "FAIL") {
            Write-Host $result -ForegroundColor Red
        }
        else {
            Write-Host $result -ForegroundColor Yellow
        }

        Remove-Item $tempFile -Force
    }
}
finally {
    $zip.Dispose()
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "===================================="
Write-Host " FINAL RESULT"
Write-Host "===================================="

Write-Host "Total libraries : $count"
Write-Host "Compatible      : $passed" -ForegroundColor Green
Write-Host "Incompatible    : $($failed.Count)" -ForegroundColor Red
Write-Host "Check errors    : $errors" -ForegroundColor Yellow

$reportLines = @(
    "BEYTEI DRIVER - 16KB ELF REPORT"
    "AAB: $aab"
    ""
    "Total: $count"
    "Passed: $passed"
    "Failed: $($failed.Count)"
    "Errors: $errors"
    ""
) + $results.ToArray()

$reportLines | Set-Content -Path $report -Encoding UTF8

if ($failed.Count -gt 0) {
    Write-Host ""
    Write-Host "LIBRARIES THAT NEED FIXING:" -ForegroundColor Red

    foreach ($item in $failed) {
        Write-Host "FAIL: $item" -ForegroundColor Red
    }
}
elseif ($errors -gt 0 -or $count -eq 0) {
    Write-Host "Check incomplete. Review the report." -ForegroundColor Yellow
}
else {
    Write-Host "All detected ELF LOAD segments are 16KB aligned!" -ForegroundColor Green
}

Write-Host ""
Write-Host "Report saved to:"
Write-Host $report
Write-Host ""
