param (
    [string]$NewVersion = "",
    [string]$ReleaseNotes = "• إضافة ميزة التحديث الذاتي التلقائي المباشر.`n• تحسين أداء توليد ملفات الـ PDF والاعتمادات الرسمية.`n• تحسينات شاملة على استقرار وسرعة استجابة النماذج.",
    [bool]$ForceUpdate = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Starting Automated App Release Pipeline  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Read current version from pubspec.yaml
$pubspecPath = "pubspec.yaml"
$pubspecContent = [System.IO.File]::ReadAllText((Resolve-Path $pubspecPath))

if ($pubspecContent -match "version:\s*([0-9\.]+)\+([0-9]+)") {
    $currentVersion = $matches[1]
    $currentBuild = [int]$matches[2]
} else {
    Write-Error "Could not read version from pubspec.yaml"
}

Write-Host "Current Version: v$currentVersion+$currentBuild" -ForegroundColor Yellow

# Determine new version and build number
if ([string]::IsNullOrWhiteSpace($NewVersion)) {
    $versionParts = $currentVersion.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2] + 1
    $targetVersion = "$major.$minor.$patch"
} else {
    $targetVersion = $NewVersion
}
$targetBuild = $currentBuild + 1

Write-Host "Target Release Version: v$targetVersion+$targetBuild" -ForegroundColor Green

# 2. Update pubspec.yaml
$updatedPubspec = $pubspecContent -replace "version:\s*[0-9\.]+\+[0-9]+", "version: $targetVersion+$targetBuild"
[System.IO.File]::WriteAllText((Resolve-Path $pubspecPath), $updatedPubspec)
Write-Host "Updated pubspec.yaml to $targetVersion+$targetBuild" -ForegroundColor Green

# 3. Build Release APK
Write-Host "`nBuilding Release APK..." -ForegroundColor Cyan
flutter build apk --release

$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Error "APK Build failed! File not found at $apkPath"
}

$apkSizeMB = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
Write-Host "APK Built successfully! Size: $apkSizeMB MB" -ForegroundColor Green

# 4. Copy APK to releases/ folder inside repo
if (-not (Test-Path "releases")) {
    New-Item -ItemType Directory -Path "releases" | Out-Null
}
Copy-Item -Path $apkPath -Destination "releases/app-release.apk" -Force
Write-Host "Copied APK to releases/app-release.apk inside repository." -ForegroundColor Green

# 5. Update version.json with direct raw repository URL
$today = (Get-Date).ToString("yyyy-MM-dd")
$downloadUrl = "https://github.com/TQAPPS/eforms-releases/raw/main/releases/app-release.apk"

$escapedNotes = $ReleaseNotes.Replace('"', '\"')
$versionJsonContent = @"
{
  "latest_version": "$targetVersion",
  "build_number": $targetBuild,
  "apk_url": "$downloadUrl",
  "release_notes": "$escapedNotes",
  "force_update": $($ForceUpdate.ToString().ToLower()),
  "publish_date": "$today"
}
"@

[System.IO.File]::WriteAllText((Resolve-Path "version.json"), $versionJsonContent, [System.Text.Encoding]::UTF8)
Write-Host "Updated version.json with direct download URL and metadata." -ForegroundColor Green

# 6. Git Commit and Push to GitHub (including APK and version.json)
Write-Host "`nPushing APK and release metadata to GitHub..." -ForegroundColor Cyan
git add pubspec.yaml version.json releases/app-release.apk
git commit -m "release: v$targetVersion+$targetBuild - $ReleaseNotes"
git tag -a "v$targetVersion" -m "Release v$targetVersion" -f
git push origin main --tags -f

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "Release v$targetVersion+$targetBuild published with APK to GitHub successfully!" -ForegroundColor Green
Write-Host "Users will now receive the update directly from the repo APK!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
