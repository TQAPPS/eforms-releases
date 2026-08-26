param (
    [string]$NewVersion = "",
    [string]$ReleaseNotes = "• تحسينات عامة وإصلاحات في الأداء.",
    [bool]$ForceUpdate = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  🚀 بدء عملية تصدير ونشر التحديث الجديد  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. قراءة واستخراج الإصدار الحالي من pubspec.yaml
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath -Raw

if ($pubspecContent -match 'version:\s*([0-9\.]+)\+([0-9]+)') {
    $currentVersion = $matches[1]
    $currentBuild = [int]$matches[2]
} else {
    Write-Error "تعذر قراءة رقم الإصدار من pubspec.yaml"
}

Write-Host "📌 الإصدار الحالي: v$currentVersion+$currentBuild" -ForegroundColor Yellow

# تحديد رقم الإصدار والبناء الجديد
if ($NewVersion -eq "") {
    $versionParts = $currentVersion.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2] + 1
    $targetVersion = "$major.$minor.$patch"
} else {
    $targetVersion = $NewVersion
}
$targetBuild = $currentBuild + 1

Write-Host "✨ الإصدار الجديد المستهدف: v$targetVersion+$targetBuild" -ForegroundColor Green

# 2. تحديث pubspec.yaml
$updatedPubspec = $pubspecContent -replace 'version:\s*[0-9\.]+\+[0-9]+', "version: $targetVersion+$targetBuild"
Set-Content -Path $pubspecPath -Value $updatedPubspec -NoNewline
Write-Host "✅ تم تحديث pubspec.yaml إلى $targetVersion+$targetBuild" -ForegroundColor Green

# 3. بناء ملف الـ APK محلياً
Write-Host "`n🔨 جاري بناء ملف الـ APK بنسخة الـ Release..." -ForegroundColor Cyan
flutter build apk --release

$apkPath = "build/app/outputs/flutter-apk/app-release.apk"
if (-not (Test-Path $apkPath)) {
    Write-Error "فشل بناء الـ APK! لم يتم العثور على الملف."
}

$apkSizeMB = [math]::Round((Get-Item $apkPath).Length / 1MB, 2)
Write-Host "✅ تم بناء الـ APK بنجاح! الحجم: $apkSizeMB MB" -ForegroundColor Green

# 4. تحديث ملف version.json
$today = (Get-Date).ToString("yyyy-MM-dd")
$repoUrl = "https://github.com/TQAPPS/eforms-releases"
$downloadUrl = "$repoUrl/releases/download/v$targetVersion/app-release.apk"

$versionJsonContent = @"
{
  "latest_version": "$targetVersion",
  "build_number": $targetBuild,
  "apk_url": "$downloadUrl",
  "release_notes": "$ReleaseNotes",
  "force_update": $($ForceUpdate.ToString().ToLower()),
  "publish_date": "$today"
}
"@

Set-Content -Path "version.json" -Value $versionJsonContent
Write-Host "✅ تم تحديث version.json برابط التحميل المباشر وتفاصيل الإصدار." -ForegroundColor Green

# 5. عمل Commit و Tag و Push إلى GitHub
Write-Host "`n📤 جاري رفع التحديث إلى GitHub..." -ForegroundColor Cyan
git add pubspec.yaml version.json
git commit -m "release: v$targetVersion+$targetBuild - $ReleaseNotes"
git tag -a "v$targetVersion" -m "Release v$targetVersion" -f
git push origin main --tags

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "🎉 تم نشر التحديث بنجاح إلى GitHub!" -ForegroundColor Green
Write-Host "📱 الإصدار الجديد v$targetVersion سيصل لجميع المستخدمين فوراً!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
