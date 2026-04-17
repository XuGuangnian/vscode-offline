param(
    [string]$OutputDir = ".\vscode-offline-package"
)

$ErrorActionPreference = "Stop"

function Log($msg) {
    Write-Host ""
    Write-Host "==== $msg ====" -ForegroundColor Cyan
}

function EnsureDir($path) {
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path | Out-Null
    }
}

function FindCodeCmd {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd",
        "$env:ProgramFiles(x86)\Microsoft VS Code\bin\code.cmd"
    )

    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    $cmd = Get-Command code -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    throw "VS Code CLI 'code' not found."
}

function DownloadVsix($extensionId, $version, $outFile) {
    $parts = $extensionId.Split(".")
    if ($parts.Count -ne 2) {
        Write-Warning "Invalid extension ID format: $extensionId"
        return $false
    }

    $publisher = $parts[0]
    $extension = $parts[1]

    $headers = @{
        "Accept" = "application/octet-stream"
        "User-Agent" = "Mozilla/5.0"
    }

    $urls = @()

    if ($version -and $version.Trim() -ne "") {
        $urls += "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$publisher/vsextensions/$extension/$version/vspackage"
    }

    $urls += "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/$publisher/vsextensions/$extension/latest/vspackage"

    foreach ($url in $urls) {
        try {
            Invoke-WebRequest -Uri $url -OutFile $outFile -Headers $headers -UseBasicParsing
            if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -gt 0)) {
                Write-Host "Downloaded: $extensionId@$version" -ForegroundColor Green
                return $true
            }
        } catch {
            Write-Warning "Download failed: $extensionId from $url"
        }
    }

    if (Test-Path $outFile) {
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
    }

    Write-Warning "Final download failed: $extensionId@$version"
    return $false
}

# =====================

Log "Prepare directories"
EnsureDir $OutputDir
$vsixDir = Join-Path $OutputDir "vsix"
$userDir = Join-Path $OutputDir "user"
EnsureDir $vsixDir
EnsureDir $userDir

Log "Find VS Code CLI"
$codeCmd = FindCodeCmd
Write-Host "Using: $codeCmd"

Log "Export extension list"
$extList = Join-Path $OutputDir "extensions.txt"
$extVer  = Join-Path $OutputDir "extensions-with-version.txt"

& $codeCmd --list-extensions | Set-Content -Encoding UTF8 $extList
& $codeCmd --list-extensions --show-versions | Set-Content -Encoding UTF8 $extVer

Log "Copy user settings"
$userSrc = Join-Path $env:APPDATA "Code\User"

Copy-Item "$userSrc\settings.json" "$userDir\settings.json" -Force -ErrorAction SilentlyContinue
Copy-Item "$userSrc\keybindings.json" "$userDir\keybindings.json" -Force -ErrorAction SilentlyContinue
Copy-Item "$userSrc\snippets" "$userDir\snippets" -Recurse -Force -ErrorAction SilentlyContinue

Log "Download VSIX incrementally"
$lines = Get-Content $extVer | Where-Object { $_.Trim() -ne "" }

$downloaded = 0
$skipped = 0
$failed = 0

foreach ($line in $lines) {
    $extensionId = $line
    $version = ""

    if ($line -match "^(.*)@([^@]+)$") {
        $extensionId = $matches[1]
        $version = $matches[2]
    }

    $prefix = $extensionId.Replace(".", "-")
    $safeName = $prefix
    if ($version -ne "") {
        $safeName = "$safeName-$version"
    }

    $outFile = Join-Path $vsixDir "$safeName.vsix"

    if (Test-Path $outFile) {
        Write-Host "Skip existing: $extensionId@$version" -ForegroundColor DarkYellow
        $skipped++
        continue
    }

    Get-ChildItem $vsixDir -Filter "$prefix-*.vsix" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $ok = DownloadVsix $extensionId $version $outFile
    if ($ok) {
        $downloaded++
    } else {
        $failed++
    }
}

Log "Create ZIP package"
$zipPath = "$OutputDir.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Compress-Archive -Path "$OutputDir\*" -DestinationPath $zipPath

Log "Summary"
Write-Host "Downloaded: $downloaded" -ForegroundColor Green
Write-Host "Skipped:    $skipped" -ForegroundColor Yellow
Write-Host "Failed:     $failed" -ForegroundColor Red

Log "DONE"
Write-Host "Output: $OutputDir" -ForegroundColor Yellow
Write-Host "Zip:    $zipPath" -ForegroundColor Yellow