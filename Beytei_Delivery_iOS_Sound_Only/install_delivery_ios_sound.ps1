param(
    [string]$ProjectPath = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-File([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing $Description: $Path"
    }
}

function Replace-OnlyOnce([string]$Text, [string]$Marker, [string]$Replacement, [string]$Description) {
    $start = $Text.IndexOf($Marker, [StringComparison]::Ordinal)
    if ($start -lt 0) { throw "Unknown Xcode project format: missing $Description" }
    if ($Text.IndexOf($Marker, $start + $Marker.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Unknown Xcode project format: duplicated $Description"
    }
    return $Text.Replace($Marker, $Replacement)
}

$ProjectPath = [IO.Path]::GetFullPath($ProjectPath)
$packageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceAudio = Join-Path $packageRoot 'ios\Runner\woo_sound.caf'
$entryPath = Join-Path $ProjectPath 'lib\dev\tx.dart'
$pbxPath = Join-Path $ProjectPath 'ios\Runner.xcodeproj\project.pbxproj'
$targetAudio = Join-Path $ProjectPath 'ios\Runner\woo_sound.caf'

Write-Host '=== BEYTEI DELIVERY COURIER - iOS SOUND ONLY ===' -ForegroundColor Cyan
Write-Host "Project: $ProjectPath"
Assert-File $sourceAudio 'CAF ringtone in this package'
Assert-File $entryPath 'DELIVERY app entrypoint lib/dev/tx.dart'
Assert-File $pbxPath 'Xcode project.pbxproj'

$deliveryCode = [IO.File]::ReadAllText($entryPath)
if (-not ($deliveryCode.Contains('class NotificationService') -and $deliveryCode.Contains("sound: 'woo_sound.caf'"))) {
    throw 'Courier entrypoint does not contain the expected notification sound. No files were changed.'
}

$bytes = [IO.File]::ReadAllBytes($sourceAudio)
if ($bytes.Length -lt 8 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'caff') {
    throw 'Supplied woo_sound.caf is not a CAF file. No files were changed.'
}

$pbx = [IO.File]::ReadAllText($pbxPath)
$nl = if ($pbx.Contains("`r`n")) { "`r`n" } else { "`n" }
$fileId = 'BEE700000000000000000002'
$buildId = 'BEE700000000000000000001'
$exists = $pbx.Contains('woo_sound.caf')

if (-not $exists) {
    if ($pbx.Contains($fileId) -or $pbx.Contains($buildId)) {
        throw 'Conflicting Xcode IDs; no files changed.'
    }

    $pbx = Replace-OnlyOnce $pbx '/* Begin PBXBuildFile section */' (
        '/* Begin PBXBuildFile section */' + $nl +
        "`t" + $buildId + ' /* woo_sound.caf in Resources */ = {isa = PBXBuildFile; fileRef = ' + $fileId + ' /* woo_sound.caf */; };'
    ) 'PBXBuildFile section'

    $pbx = Replace-OnlyOnce $pbx '/* Begin PBXFileReference section */' (
        '/* Begin PBXFileReference section */' + $nl +
        "`t" + $fileId + ' /* woo_sound.caf */ = {isa = PBXFileReference; lastKnownFileType = audio.caf; path = woo_sound.caf; sourceTree = "<group>"; };'
    ) 'PBXFileReference section'

    $runnerAnchor = 'DX_PUSH_ENTITLEMENTS /* Runner.entitlements */,'
    $pbx = Replace-OnlyOnce $pbx $runnerAnchor (
        $runnerAnchor + $nl + "`t`t`t`t" + $fileId + ' /* woo_sound.caf */,'
    ) 'Runner group'

    $resourceAnchor = '97C147011CF9000F007C117D /* LaunchScreen.storyboard in Resources */,'
    $pbx = Replace-OnlyOnce $pbx $resourceAnchor (
        $resourceAnchor + $nl + "`t`t`t`t" + $buildId + ' /* woo_sound.caf in Resources */,'
    ) 'Runner resources'
} else {
    if (-not ($pbx.Contains('woo_sound.caf in Resources') -and
               $pbx.Contains('path = woo_sound.caf;'))) {
        throw 'A different or incomplete Xcode sound configuration was found; no files changed.'
    }
    Write-Host 'Existing Xcode sound entry detected.' -ForegroundColor Yellow
}

$backup = Join-Path $ProjectPath ('.beytei_delivery_ios_backup_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $pbxPath -Destination (Join-Path $backup 'project.pbxproj')
if (Test-Path -LiteralPath $targetAudio) {
    Copy-Item -LiteralPath $targetAudio -Destination (Join-Path $backup 'woo_sound.caf')
}

# Only iOS files are changed. Flutter/Dart and Android files are untouched.
[IO.File]::WriteAllText($pbxPath, $pbx, [Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $sourceAudio -Destination $targetAudio -Force

$finalPbx = [IO.File]::ReadAllText($pbxPath)
if (-not ($finalPbx.Contains('woo_sound.caf in Resources') -and
          $finalPbx.Contains('path = woo_sound.caf;') -and
          (Test-Path -LiteralPath $targetAudio))) {
    Copy-Item -LiteralPath (Join-Path $backup 'project.pbxproj') -Destination $pbxPath -Force
    throw "Post-install verification failed; restored project.pbxproj from $backup"
}

Write-Host '[OK] CAF added to ios/Runner/woo_sound.caf' -ForegroundColor Green
Write-Host '[OK] Xcode Copy Bundle Resources updated' -ForegroundColor Green
Write-Host '[UNCHANGED] lib/dev/tx.dart and every other Dart/Android file' -ForegroundColor Green
Write-Host "[BACKUP] $backup" -ForegroundColor Yellow
Write-Host ''
Write-Host 'Next: git status --short'
Write-Host '      git add ios/Runner/woo_sound.caf ios/Runner.xcodeproj/project.pbxproj'
Write-Host '      git commit -m "Include courier notification ringtone in iOS app"'
Write-Host '      git push origin main'
Write-Host 'Codemagic must build the courier entrypoint: lib/dev/tx.dart'
