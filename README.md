# vscode-offline

## Overview
This repo helps you **export VS Code extensions on a machine with Internet access** and **install them later on an offline machine**.

## Usage
### Export (online machine)

```powershell
# If an extension already exists locally, it will be skipped.
# If you want to download newer versions, clean old ones first.
powershell -ExecutionPolicy Bypass -File .\export-vscode.ps1
```

### Import (offline machine)

```powershell
powershell -ExecutionPolicy Bypass -File .\import-vscode.ps1
```

## Import options
### Option 1: Import all (default)

```powershell
.\import-vscode.ps1
```

### Option 2: Import only selected extensions (include list / whitelist)

```powershell
.\import-vscode.ps1 -Include "ms-python.python","esbenp.prettier-vscode"
```

### Option 3: Exclude some extensions (exclude list / blacklist)

```powershell
.\import-vscode.ps1 -Exclude "github.copilot","ms-vscode.remote-ssh"
```

### Option 4: Filter by keyword

```powershell
.\import-vscode.ps1 -Filter "python"
```

This installs all extensions whose name contains `python`.

### Recommended: manage a list file
You can maintain an "extension list file", for example `install-list.txt`:

```text
ms-python.python
esbenp.prettier-vscode
dbaeumer.vscode-eslint
```

Then import using that list:

```powershell
$plugins = Get-Content .\install-list.txt
.\import-vscode.ps1 -Include $plugins
```