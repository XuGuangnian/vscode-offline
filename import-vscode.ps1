param(
    [string]$PackageDir = ".\vscode-offline-package",
    [string[]]$Include,
    [string[]]$Exclude,
    [string]$Filter
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

function AssertPathExists($path, $hint) {
    if (!(Test-Path $path)) {
        Write-Host ""
        Write-Host "ERROR: Path not found: $path" -ForegroundColor Red
        if ($hint) {
            Write-Host $hint -ForegroundColor Yellow
        }
        throw "Missing required path: $path"
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

function MatchExtension($fileName, $Include, $Exclude, $Filter) {
    $name = $fileName.ToLower()

    if ($Include -and $Include.Count -gt 0) {
        foreach ($i in $Include) {
            if ($name -like "*$($i.ToLower())*") {
                return $true
            }
        }
        return $false
    }

    if ($Exclude -and $Exclude.Count -gt 0) {
        foreach ($e in $Exclude) {
            if ($name -like "*$($e.ToLower())*") {
                return $false
            }
        }
    }

    if ($Filter) {
        return $name -like "*$($Filter.ToLower())*"
    }

    return $true
}

# =====================

$expectedDefault = ".\vscode-offline-package"
if ($PackageDir -eq "." -and (Test-Path $expectedDefault)) {
    $PackageDir = $expectedDefault
}

$vsixDir = Join-Path $PackageDir "vsix"
$userDir = Join-Path $PackageDir "user"

AssertPathExists $PackageDir "Hint: run .\export-vscode.ps1 on an online machine, then copy/unzip the folder 'vscode-offline-package' next to this script; or pass -PackageDir explicitly."
AssertPathExists $vsixDir "Hint: expected VSIX files under '$vsixDir'. Make sure you copied/unzipped the export package completely."
EnsureDir $userDir

Log "Find VS Code CLI"
$codeCmd = FindCodeCmd
Write-Host "Using: $codeCmd"

Log "Select VSIX files"

$allFiles = Get-ChildItem $vsixDir -Filter *.vsix -File
$selected = @()

foreach ($file in $allFiles) {
    if (MatchExtension $file.Name $Include $Exclude $Filter) {
        $selected += $file
    }
}

Write-Host "Total VSIX: $($allFiles.Count)"
Write-Host "Selected:   $($selected.Count)"

if ($selected.Count -eq 0) {
    Write-Warning "No extensions selected. Exit."
    return
}

Log "Install extensions"

foreach ($file in $selected) {
    Write-Host "Installing: $($file.Name)"
    & $codeCmd --install-extension $file.FullName --force
}

Log "Restore settings"

$userDst = Join-Path $env:APPDATA "Code\User"

Copy-Item "$userDir\settings.json" "$userDst\settings.json" -Force -ErrorAction SilentlyContinue
Copy-Item "$userDir\keybindings.json" "$userDst\keybindings.json" -Force -ErrorAction SilentlyContinue
Copy-Item "$userDir\snippets" "$userDst\snippets" -Recurse -Force -ErrorAction SilentlyContinue

Log "DONE"
Write-Host "Restart VS Code to apply changes." -ForegroundColor Yellow