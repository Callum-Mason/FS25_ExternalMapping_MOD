# FS25 External Mapping Mod Build Script
# Usage: .\build.ps1 [-Version "1.2.3.4"] [-Dev]

param(
    [string]$Version,  # Specific version to set (e.g., "1.2.0.0")
    [switch]$Dev       # Create DEV version instead of production
)

$ErrorActionPreference = "Stop"

# Configuration
$ModName = "FS25_ExternalMapping"
$ModNameDev = "${ModName}_DEV"
$SourceDir = $PSScriptRoot
$BuildDir = Join-Path $PSScriptRoot "build"
$OutputDir = Split-Path $SourceDir -Parent

# Files to include in the mod ZIP
$FilesToInclude = @(
    "icon.png",
    "modDesc.xml",
    "scripts\*.lua"
)

Write-Host "=== FS25 External Mapping Build Script ===" -ForegroundColor Cyan
Write-Host ""

# Read current version from modDesc.xml
$modDescPath = Join-Path $SourceDir "modDesc.xml"
if (-not (Test-Path $modDescPath)) {
    Write-Host "ERROR: modDesc.xml not found!" -ForegroundColor Red
    exit 1
}

[xml]$modDescXml = Get-Content $modDescPath
$currentVersion = $modDescXml.modDesc.version

Write-Host "Current version: $currentVersion" -ForegroundColor Yellow

# Calculate new version
if ($Version) {
    $newVersion = $Version
    Write-Host "Setting version to: $newVersion (manual)" -ForegroundColor Green
}
else {
    # Auto-increment by 0.0.1.0
    $versionParts = $currentVersion.Split('.')
    if ($versionParts.Count -eq 4) {
        $versionParts[2] = [int]$versionParts[2] + 1
        $newVersion = $versionParts -join '.'
    }
    else {
        Write-Host "ERROR: Version format invalid. Expected x.x.x.x" -ForegroundColor Red
        exit 1
    }
    Write-Host "Auto-incrementing to: $newVersion" -ForegroundColor Green
}

# Determine mod name and title suffix
$targetModName = if ($Dev) { $ModNameDev } else { $ModName }
$titleSuffix = if ($Dev) { " [DEV]" } else { "" }

Write-Host "Building: $targetModName" -ForegroundColor Cyan
Write-Host ""

# Create clean build directory
if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
}
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null

Write-Host "Copying files..." -ForegroundColor Yellow

# Copy icon.png
if (Test-Path (Join-Path $SourceDir "icon.png")) {
    Copy-Item (Join-Path $SourceDir "icon.png") $BuildDir
    Write-Host "  OK icon.png" -ForegroundColor Green
}
else {
    Write-Host "  MISSING icon.png" -ForegroundColor Red
    exit 1
}

# Copy scripts directory
$scriptsSourceDir = Join-Path $SourceDir "scripts"
$scriptsDestDir = Join-Path $BuildDir "scripts"
if (Test-Path $scriptsSourceDir) {
    New-Item -ItemType Directory -Path $scriptsDestDir -Force | Out-Null
    Get-ChildItem -Path $scriptsSourceDir -Filter "*.lua" | ForEach-Object {
        Copy-Item $_.FullName $scriptsDestDir
        Write-Host ("  OK scripts/" + $_.Name) -ForegroundColor Green
    }
}
else {
    Write-Host "  ERROR: scripts directory NOT FOUND!" -ForegroundColor Red
    exit 1
}

# Copy and modify modDesc.xml
Write-Host "Updating modDesc.xml..." -ForegroundColor Yellow
[xml]$buildModDesc = Get-Content $modDescPath

# Update version
$buildModDesc.modDesc.version = $newVersion

# Update title for DEV or production builds
$titleNode = $buildModDesc.modDesc.title.en
if ($Dev) {
    if ($titleNode -notlike "*[DEV]*") {
        $buildModDesc.modDesc.title.en = $titleNode + " [DEV]"
    }
}
else {
    # remove any existing [DEV] tag for production builds
    $buildModDesc.modDesc.title.en = $titleNode -replace '\s*\[DEV\]\s*', ''
}

# Save modified modDesc.xml to build directory
$buildModDescPath = Join-Path $BuildDir "modDesc.xml"
$buildModDesc.Save($buildModDescPath)
Write-Host "  OK modDesc.xml (version: $newVersion)" -ForegroundColor Green

Write-Host ""
Write-Host "Creating ZIP archive..." -ForegroundColor Yellow

# Create ZIP file
$zipFileName = "${targetModName}.zip"
$zipFilePath = Join-Path $OutputDir $zipFileName

if (Test-Path $zipFilePath) {
    Remove-Item $zipFilePath -Force
}

if ($Dev) {
    # For DEV builds, produce an unzipped folder with the DEV tag
    # avoid colliding with the source folder; create a separate unzipped DEV folder
    $devOutputDir = Join-Path $OutputDir ($targetModName + "_UNZIPPED")
    if (Test-Path $devOutputDir) {
        Remove-Item $devOutputDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $devOutputDir -Force | Out-Null
    Copy-Item -Path (Join-Path $BuildDir '*') -Destination $devOutputDir -Recurse -Force
    Write-Host "  OK (DEV) copied to $devOutputDir" -ForegroundColor Green
}
else {
    # Compress the build directory contents for production
    Compress-Archive -Path "$BuildDir\*" -DestinationPath $zipFilePath -CompressionLevel Optimal
    Write-Host "  OK $zipFileName" -ForegroundColor Green
}

# Clean up build directory
Remove-Item $BuildDir -Recurse -Force

# Update source modDesc.xml version (only for production builds)
if (-not $Dev) {
    Write-Host ""
    Write-Host "Updating source modDesc.xml version..." -ForegroundColor Yellow
    $modDescXml.modDesc.version = $newVersion
    # Ensure source title doesn't keep a [DEV] tag
    $sourceTitle = $modDescXml.modDesc.title.en
    $modDescXml.modDesc.title.en = $sourceTitle -replace '\s*\[DEV\]\s*', ''
    $modDescXml.Save($modDescPath)
    Write-Host "  OK Source version updated to $newVersion" -ForegroundColor Green
}

# Re-add [DEV] tag to the workspace project title after production build (force: strip then append)
if (-not $Dev) {
    $currentSourceTitle = $modDescXml.modDesc.title.en
    # strip any existing [DEV] and whitespace, then append single [DEV]
    $cleanTitle = ($currentSourceTitle -replace '\s*\[DEV\]\s*', '')
    $modDescXml.modDesc.title.en = ($cleanTitle.Trim() + " [DEV]")
    $modDescXml.Save($modDescPath)
    Write-Host "  OK Re-added [DEV] to source modDesc.xml (forced)" -ForegroundColor Yellow
}

# Display results
Write-Host ""
Write-Host "=== Build Complete ===" -ForegroundColor Cyan
if ($Dev) {
    Write-Host "Output: $devOutputDir" -ForegroundColor White
    # calculate total folder size for DEV output
    $sum = (Get-ChildItem -Path $devOutputDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
    Write-Host "Size: $([math]::Round(($sum) / 1KB, 2)) KB" -ForegroundColor White
    Write-Host "Version: $newVersion" -ForegroundColor White
}
else {
    Write-Host "Output: $zipFilePath" -ForegroundColor White
    $zipInfo = Get-Item $zipFilePath
    Write-Host "Size: $([math]::Round($zipInfo.Length / 1KB, 2)) KB" -ForegroundColor White
    Write-Host "Version: $newVersion" -ForegroundColor White
}
if ($Dev) {
    Write-Host "Type: DEVELOPMENT BUILD" -ForegroundColor Yellow
}
else {
    Write-Host "Type: PRODUCTION RELEASE" -ForegroundColor Green
}
Write-Host ""

#test