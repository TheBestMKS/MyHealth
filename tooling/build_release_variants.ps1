param(
    [string]$Flutter = "N:\Codex\Compilers\flutter\bin\flutter.bat",
    [string]$InnoCompiler = "",
    [switch]$SkipWindows,
    [switch]$SkipAndroid,
    [switch]$LiteOnly
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$version = "1.8.1"
$dist = Join-Path $root "dist\$version"
$modelName = "qwen3.5-0.8b-ablate-e2-opus46-postopus-runtime.Q4_K_M.gguf"
$projectorName = "mmproj-Qwen3.5-0.8B-F16.gguf"
$modelPath = Join-Path $root "assets\models\$modelName"
$projectorPath = Join-Path $root "assets\models\$projectorName"
$expected = @{
    $modelName = @{ Length = 527502816; Sha256 = "3b1c1d041bd370fdcc742cf68b66dc2af8d45c8581d2e408949e8130fa2ad757" }
    $projectorName = @{ Length = 204987104; Sha256 = "d149f5a48fa7a0051ee9143e731d69ca82ffe43aa75bec63b18ea340709887f8" }
}

function Invoke-Flutter([string[]]$Arguments) {
    & $Flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Assert-Model([string]$Path) {
    $file = Get-Item -LiteralPath $Path
    $record = $expected[$file.Name]
    if ($null -eq $record -or $file.Length -ne $record.Length) {
        throw "Unexpected model size: $($file.FullName)"
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
    if ($hash -ne $record.Sha256) {
        throw "Model checksum mismatch: $($file.FullName)"
    }
}

function Resolve-InnoCompiler {
    if ($InnoCompiler -and (Test-Path -LiteralPath $InnoCompiler)) {
        return (Resolve-Path -LiteralPath $InnoCompiler).Path
    }
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    foreach ($candidate in @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return ""
}

function Copy-WindowsRelease([string]$Edition, [string]$Slug) {
    $source = Join-Path $root "build\windows\x64\runner\Release"
    $target = Join-Path $dist "MyHealth-Windows-$Slug-$version"
    $resolvedDist = [IO.Path]::GetFullPath($dist).TrimEnd('\') + '\'
    $resolvedTarget = [IO.Path]::GetFullPath($target)
    if (-not $resolvedTarget.StartsWith($resolvedDist, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to replace a directory outside the release folder: $resolvedTarget"
    }
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    Copy-Item -LiteralPath $source -Destination $target -Recurse
    $zip = "$target.zip"
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    Compress-Archive -Path (Join-Path $target "*") -DestinationPath $zip -CompressionLevel Optimal

    $iscc = Resolve-InnoCompiler
    if ($iscc) {
        $artifact = "MyHealth-Windows-$Slug-Setup-$version"
        & $iscc "/DSourceDir=$target" "/DOutputDir=$dist" "/DEdition=$Edition" "/DArtifactName=$artifact" "/DMyAppVersion=$version" (Join-Path $root "tooling\windows_installer.iss")
        if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE" }
    } else {
        Write-Warning "Inno Setup is not installed; the portable ZIP was still created."
    }
}

function Copy-AndroidRelease([string]$Slug) {
    $source = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
    Copy-Item -LiteralPath $source -Destination (Join-Path $dist "MyHealth-Android-$Slug-$version.apk") -Force
}

function Build-Edition([string]$Edition, [string]$Slug, [bool]$Bundled) {
    Push-Location $root
    try {
        $gradleWrapper = Join-Path $root "android\gradlew.bat"
        if (Test-Path -LiteralPath $gradleWrapper) {
            & $gradleWrapper --stop
            if ($LASTEXITCODE -ne 0) {
                throw "gradlew --stop failed with exit code $LASTEXITCODE"
            }
        }
        Invoke-Flutter @("clean")
        $buildDirectory = Join-Path $root "build"
        if (Test-Path -LiteralPath $buildDirectory) {
            throw "flutter clean left a stale build directory: $buildDirectory"
        }
        Invoke-Flutter @("pub", "get")
        $define = if ($Bundled) { @("--dart-define=MYHEALTH_BUNDLED_LLM=true") } else { @() }
        if (-not $SkipWindows) {
            Invoke-Flutter (@("build", "windows", "--release") + $define)
            Copy-WindowsRelease $Edition $Slug
        }
        if (-not $SkipAndroid) {
            Invoke-Flutter (@("build", "apk", "--release") + $define)
            Copy-AndroidRelease $Slug
        }
    } finally {
        Pop-Location
    }
}

Assert-Model $modelPath
Assert-Model $projectorPath
New-Item -ItemType Directory -Path $dist -Force | Out-Null
if (-not $LiteOnly) {
    Build-Edition "Full + Qwen3.5 0.8B" "Full-Qwen3.5-0.8B" $true
}

$staging = Join-Path ([IO.Path]::GetTempPath()) "MyHealth-model-staging-$PID"
New-Item -ItemType Directory -Path $staging -Force | Out-Null
try {
    Move-Item -LiteralPath $modelPath -Destination (Join-Path $staging $modelName)
    Move-Item -LiteralPath $projectorPath -Destination (Join-Path $staging $projectorName)
    Build-Edition "Lite, no model" "Lite-No-Model" $false
} finally {
    foreach ($name in @($modelName, $projectorName)) {
        $source = Join-Path $staging $name
        $destination = Join-Path $root "assets\models\$name"
        if (Test-Path -LiteralPath $source) {
            Move-Item -LiteralPath $source -Destination $destination -Force
        }
    }
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Force }
}

$checksums = Get-ChildItem -LiteralPath $dist -File |
    Where-Object Name -ne "SHA256SUMS.txt" |
    Sort-Object Name |
    ForEach-Object {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    "$hash  $($_.Name)"
}
Set-Content -LiteralPath (Join-Path $dist "SHA256SUMS.txt") -Value $checksums -Encoding utf8
Write-Host "Release artifacts: $dist"
