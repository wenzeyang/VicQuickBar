<#
.SYNOPSIS
    Build the standalone Vic Quick Bar x64 portable ZIP.

.DESCRIPTION
    Compiles MaterialBar.ahk with AutoHotkey v2, copies only runtime assets,
    runs the compiled EXE smoke test in isolation, removes generated state,
    and creates a versioned ZIP plus SHA-256 file under dist\.
#>

#Requires -Version 5.1

param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"
$projectRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$sourcePath = Join-Path $projectRoot "MaterialBar.ahk"
$basePath = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
$compilerCandidates = @(
    (Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey\Compiler\Ahk2Exe.exe"),
    (Join-Path $env:USERPROFILE "AppData\Local\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"),
    "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
)
$compilerPath = $compilerCandidates |
    Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
    Select-Object -First 1

if (-not $compilerPath) {
    throw "Ahk2Exe.exe was not found. Install the official compiler first."
}
if (-not (Test-Path -LiteralPath $basePath -PathType Leaf)) {
    throw "AutoHotkey v2 x64 base was not found: $basePath"
}
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Source file was not found: $sourcePath"
}

$sourceText = Get-Content -LiteralPath $sourcePath -Raw
if ($sourceText -notmatch ';@Ahk2Exe-SetVersion\s+1\.0\.0\.0') {
    throw "MaterialBar.ahk does not declare version 1.0.0.0."
}

$distRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "dist"))
$packageName = "VicQuickBar-v$Version-win-x64-portable"
$packageDir = [System.IO.Path]::GetFullPath(
    (Join-Path $distRoot $packageName))
$zipPath = [System.IO.Path]::GetFullPath(
    (Join-Path $distRoot ($packageName + ".zip")))
$hashPath = [System.IO.Path]::GetFullPath(
    (Join-Path $distRoot ($packageName + ".sha256.txt")))
$distPrefix = $distRoot.TrimEnd('\') + '\'

foreach ($target in @($packageDir, $zipPath, $hashPath)) {
    if (-not $target.StartsWith($distPrefix,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe output path: $target"
    }
}

New-Item -ItemType Directory -Path $distRoot -Force | Out-Null
if (Test-Path -LiteralPath $packageDir) {
    Remove-Item -LiteralPath $packageDir -Recurse -Force
}
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
if (Test-Path -LiteralPath $hashPath) {
    Remove-Item -LiteralPath $hashPath -Force
}

New-Item -ItemType Directory -Path $packageDir | Out-Null
$assetOutput = Join-Path $packageDir "assets"
New-Item -ItemType Directory -Path $assetOutput | Out-Null

$exePath = Join-Path $packageDir "VicQuickBar.exe"
$compileArgs = "/in `"$sourcePath`" /out `"$exePath`" " +
    "/base `"$basePath`" /icon `"$projectRoot\assets\app.ico`" /compress 0"
$compile = Start-Process -FilePath $compilerPath `
    -ArgumentList $compileArgs -WindowStyle Hidden -Wait -PassThru
if ($compile.ExitCode -ne 0 -or
    -not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
    throw "Ahk2Exe compilation failed with exit code $($compile.ExitCode)."
}

Copy-Item -LiteralPath (Join-Path $projectRoot "material-bar.example.ini") `
    -Destination $packageDir
Copy-Item -LiteralPath (Join-Path $projectRoot "PORTABLE_README.md") `
    -Destination (Join-Path $packageDir "使用说明.md")
Copy-Item -LiteralPath (Join-Path $projectRoot "THIRD_PARTY_NOTICES.md") `
    -Destination $packageDir
foreach ($assetName in @("app.ico", "tray.ico", "empty-folder.ico")) {
    Copy-Item -LiteralPath (Join-Path $projectRoot "assets\$assetName") `
        -Destination $assetOutput
}

$smoke = Start-Process -FilePath $exePath -ArgumentList "--smoke-test" `
    -WorkingDirectory $packageDir -WindowStyle Hidden -PassThru
if (-not $smoke.WaitForExit(30000)) {
    $smoke.Kill()
    throw "Compiled EXE smoke test timed out."
}
if ($smoke.ExitCode -ne 0) {
    throw "Compiled EXE smoke test failed with exit code $($smoke.ExitCode)."
}

# The smoke test creates first-run state in the isolated package directory.
# Remove it so the published ZIP never contains developer or test data.
$generatedConfig = Join-Path $packageDir "material-bar.ini"
$generatedData = [System.IO.Path]::GetFullPath((Join-Path $packageDir "data"))
$packagePrefix = $packageDir.TrimEnd('\') + '\'
if (Test-Path -LiteralPath $generatedConfig) {
    Remove-Item -LiteralPath $generatedConfig -Force
}
if (Test-Path -LiteralPath $generatedData) {
    if (-not $generatedData.StartsWith($packagePrefix,
        [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe generated data path: $generatedData"
    }
    Remove-Item -LiteralPath $generatedData -Recurse -Force
}

Compress-Archive -LiteralPath $packageDir -DestinationPath $zipPath `
    -CompressionLevel Optimal
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
[System.IO.File]::WriteAllText($hashPath,
    ($hash.ToLowerInvariant() + "  " + [System.IO.Path]::GetFileName($zipPath) +
    [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))

Write-Host "Portable package created: $zipPath"
Write-Host "SHA-256: $($hash.ToLowerInvariant())"

