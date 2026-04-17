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
        return
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
                Write-Host "Downloaded: $extensionId" -ForegroundColor Green
                return
            }
        } catch {
            Write-Warning "Download failed: $extensionId"
        }
    }
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

Log "Download VSIX"
$lines = Get-Content $extVer | Where-Object { $_.Trim() -ne "" }

foreach ($line in $lines) {
    $extensionId = $line
    $version = ""

    if ($line -match "^(.*)@([^@]+)$") {
        $extensionId = $matches[1]
        $version = $matches[2]
    }

    $safeName = $extensionId.Replace(".", "-")
    if ($version -ne "") {
        $safeName = "$safeName-$version"
    }

    $outFile = Join-Path $vsixDir "$safeName.vsix"
    DownloadVsix $extensionId $version $outFile
}

Log "Create ZIP package"
$zipPath = "$OutputDir.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}
Compress-Archive -Path "$OutputDir\*" -DestinationPath $zipPath

Log "DONE"
Write-Host "Output: $OutputDir" -ForegroundColor Yellow
Write-Host "Zip: $zipPath" -ForegroundColor Yellow