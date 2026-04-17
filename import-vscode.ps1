param(
    [string]$PackageDir = "."
)

$ErrorActionPreference = "Stop"

function Log($msg) {
    Write-Host ""
    Write-Host "==== $msg ====" -ForegroundColor Cyan
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

# =====================

$vsixDir = Join-Path $PackageDir "vsix"
$userDir = Join-Path $PackageDir "user"

Log "Find VS Code CLI"
$codeCmd = FindCodeCmd
Write-Host "Using: $codeCmd"

Log "Install VSIX"
Get-ChildItem $vsixDir -Filter *.vsix | ForEach-Object {
    Write-Host "Installing: $($_.Name)"
    & $codeCmd --install-extension $_.FullName --force
}

Log "Restore settings"
$userDst = Join-Path $env:APPDATA "Code\User"

Copy-Item "$userDir\settings.json" "$userDst\settings.json" -Force -ErrorAction SilentlyContinue
Copy-Item "$userDir\keybindings.json" "$userDst\keybindings.json" -Force -ErrorAction SilentlyContinue
Copy-Item "$userDir\snippets" "$userDst\snippets" -Recurse -Force -ErrorAction SilentlyContinue

Log "DONE"
Write-Host "Restart VS Code to apply changes." -ForegroundColor Yellow