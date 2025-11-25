#Requires -Version 5.1

<#
.SYNOPSIS
    Uninstalls Claude Code from Windows systems.

.DESCRIPTION
    This script removes Claude Code and all associated files, including:
    - Binary files
    - Shell/profile integration
    - Configuration and cache files
    - NPM installations

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER Quiet
    Suppress non-error output (implies -Force).

.EXAMPLE
    .\uninstall-claude.ps1
    
.EXAMPLE
    .\uninstall-claude.ps1 -Force
    
.EXAMPLE
    .\uninstall-claude.ps1 -Quiet
#>

[CmdletBinding()]
param(
    [Alias("f")]
    [switch]$Force,
    
    [Alias("q")]
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

if ($Quiet) {
    $Force = $true
}

function Write-LogInfo {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
        Write-Host $Message
    }
}

function Write-LogSuccess {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "[SUCCESS] " -ForegroundColor Green -NoNewline
        Write-Host $Message
    }
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# Platform detection
$arch = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
    "X64" { "x64" }
    "Arm64" { "arm64" }
    default { 
        Write-LogError "Unsupported architecture: $([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)"
        exit 1
    }
}

$platform = "windows-$arch"
Write-LogInfo "Detected platform: $platform"

# Define paths for Windows
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$LocalAppData = $env:LOCALAPPDATA
$AppData = $env:APPDATA
$ProgramFiles = $env:ProgramFiles
$ProgramFilesX86 = ${env:ProgramFiles(x86)}

$BinaryPaths = @(
    (Join-Path $LocalAppData "Programs\Claude\claude.exe"),
    (Join-Path $LocalAppData "Claude\claude.exe"),
    (Join-Path $ProgramFiles "Claude\claude.exe"),
    (Join-Path $env:USERPROFILE ".local\bin\claude.exe"),
    (Join-Path $env:USERPROFILE "bin\claude.exe"),
    (Join-Path $AppData "npm\claude.cmd"),
    (Join-Path $AppData "npm\claude.ps1"),
    (Join-Path $AppData "npm\claude")
)

$NpmPaths = @(
    (Join-Path $AppData "npm\node_modules\@anthropic-ai\claude-code"),
    (Join-Path $ProgramFiles "nodejs\node_modules\@anthropic-ai\claude-code"),
    (Join-Path $env:USERPROFILE ".npm-global\lib\node_modules\@anthropic-ai\claude-code")
)

$ClaudeInstallDirs = @(
    (Join-Path $LocalAppData "Programs\Claude"),
    (Join-Path $LocalAppData "Claude"),
    (Join-Path $ProgramFiles "Claude")
)

$ProfilePaths = @(
    $PROFILE.CurrentUserCurrentHost,
    $PROFILE.CurrentUserAllHosts,
    $PROFILE.AllUsersCurrentHost,
    $PROFILE.AllUsersAllHosts,
    (Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"),
    (Join-Path $env:USERPROFILE "Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
) | Where-Object { $_ -ne $null } | Select-Object -Unique

function Find-ClaudeBinary {
    foreach ($path in $BinaryPaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    
    $cmdPath = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmdPath) {
        return $cmdPath.Source
    }
    
    $cmdPath = Get-Command claude.exe -ErrorAction SilentlyContinue
    if ($cmdPath) {
        return $cmdPath.Source
    }
    
    return $null
}

function Get-InstallationType {
    $claudeBinary = Find-ClaudeBinary
    
    if ($claudeBinary) {
        try {
            $version = & $claudeBinary --version 2>$null
            if ($version -match "Claude Code") {
                if ($claudeBinary -match "node_modules.*@anthropic-ai.*claude-code") {
                    return "npm"
                }
                else {
                    return "native"
                }
            }
            else {
                return "unknown"
            }
        }
        catch {
            return "unknown"
        }
    }
    
    return "none"
}

function Remove-ProfileIntegration {
    $removedCount = 0
    
    foreach ($profilePath in $ProfilePaths) {
        if (Test-Path $profilePath) {
            try {
                $backupPath = "$profilePath.claude-backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item $profilePath $backupPath -ErrorAction SilentlyContinue
                
                $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    $originalContent = $content
                    
                    $content = $content -replace '(?ms)# Claude Code integration.*?# End Claude Code integration\r?\n?', ''
                    $content = $content -replace '(?m)^.*claude.*completion.*$\r?\n?', ''
                    $content = $content -replace '(?m)^.*claude.*autocompletion.*$\r?\n?', ''
                    $content = $content -replace '(?m)^\s*\$env:CLAUDE.*$\r?\n?', ''
                    $content = $content -replace '(?m)^.*Set-Alias.*claude.*$\r?\n?', ''
                    
                    if ($content -ne $originalContent) {
                        Set-Content $profilePath $content -NoNewline
                        $removedCount++
                        Write-LogInfo "Cleaned profile integration from $profilePath"
                    }
                }
            }
            catch {
                Write-LogWarning "Could not clean profile: $profilePath - $_"
            }
        }
    }
    
    if ($removedCount -gt 0) {
        Write-LogSuccess "Removed profile integration from $removedCount config file(s)"
    }
}

function Invoke-ClaudeUninstall {
    $claudeBinary = Find-ClaudeBinary
    $installType = Get-InstallationType
    
    if ($claudeBinary) {
        Write-LogInfo "Found Claude binary at: $claudeBinary (Type: $installType)"
        
        try {
            $helpOutput = & $claudeBinary --help 2>$null
            if ($helpOutput -match "uninstall|remove") {
                Write-LogInfo "Running built-in claude uninstall command..."
                try {
                    & $claudeBinary uninstall 2>$null
                    Write-LogSuccess "Built-in claude uninstall command completed"
                    return $true
                }
                catch {
                    Write-LogWarning "Built-in claude uninstall command failed, proceeding with manual cleanup"
                }
            }
            else {
                Write-LogInfo "No built-in uninstall command found, proceeding with manual cleanup"
            }
        }
        catch {
            Write-LogInfo "Could not check for built-in uninstall, proceeding with manual cleanup"
        }
        
        if ($installType -eq "npm") {
            $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
            if ($npmCmd) {
                try {
                    & npm uninstall -g @anthropic-ai/claude-code 2>$null
                    Write-LogSuccess "NPM uninstall completed"
                    return $true
                }
                catch {
                    Write-LogWarning "NPM uninstall failed, proceeding with manual cleanup"
                }
            }
        }
    }
    else {
        Write-LogInfo "No Claude binary found, proceeding with manual cleanup"
    }
    
    return $false
}

function Remove-Binaries {
    $removedCount = 0
    $failedCount = 0
    
    foreach ($binaryPath in $BinaryPaths) {
        if (Test-Path $binaryPath) {
            try {
                Remove-Item $binaryPath -Force -ErrorAction Stop
                $removedCount++
                Write-LogSuccess "Removed binary: $binaryPath"
            }
            catch {
                Write-LogWarning "Could not remove $binaryPath - $_"
                $failedCount++
            }
        }
    }
    
    foreach ($installDir in $ClaudeInstallDirs) {
        if (Test-Path $installDir) {
            try {
                Remove-Item $installDir -Recurse -Force -ErrorAction Stop
                $removedCount++
                Write-LogSuccess "Removed installation directory: $installDir"
            }
            catch {
                Write-LogWarning "Could not remove $installDir - $_"
                $failedCount++
            }
        }
    }
    
    $cmdPath = Get-Command claude -ErrorAction SilentlyContinue
    if ($cmdPath -and (Test-Path $cmdPath.Source)) {
        try {
            Remove-Item $cmdPath.Source -Force -ErrorAction Stop
            $removedCount++
            Write-LogSuccess "Removed binary from PATH: $($cmdPath.Source)"
        }
        catch {
            Write-LogWarning "Could not remove $($cmdPath.Source) - $_"
            $failedCount++
        }
    }
    
    if ($removedCount -gt 0) {
        Write-LogSuccess "Removed $removedCount binary file(s)/directory(ies)"
    }
    
    return ($failedCount -eq 0)
}

function Remove-NpmInstallation {
    $removedNpm = $false
    $failed = $false
    
    Write-LogInfo "Checking for npm installation..."
    
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        try {
            $npmList = & npm list -g @anthropic-ai/claude-code 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-LogInfo "Found npm installation, using official uninstall method..."
                try {
                    & npm uninstall -g @anthropic-ai/claude-code 2>$null
                    Write-LogSuccess "Removed Claude Code via official npm uninstall"
                    $removedNpm = $true
                }
                catch {
                    Write-LogWarning "Official npm uninstall failed, trying manual cleanup"
                    $failed = $true
                }
            }
        }
        catch {
            # npm list failed, package probably not installed
        }
        
        try {
            $npmBin = & npm bin -g 2>$null
            if ($npmBin) {
                $npmClaudePaths = @(
                    (Join-Path $npmBin "claude"),
                    (Join-Path $npmBin "claude.cmd"),
                    (Join-Path $npmBin "claude.ps1")
                )
                foreach ($npmClaudePath in $npmClaudePaths) {
                    if (Test-Path $npmClaudePath) {
                        try {
                            Remove-Item $npmClaudePath -Force -ErrorAction Stop
                            Write-LogSuccess "Removed npm binary: $npmClaudePath"
                            $removedNpm = $true
                        }
                        catch {
                            Write-LogWarning "Could not remove npm binary: $npmClaudePath"
                            $failed = $true
                        }
                    }
                }
            }
        }
        catch {
            # Ignore errors getting npm bin path
        }
    }
    
    foreach ($npmPath in $NpmPaths) {
        if (Test-Path $npmPath) {
            try {
                Remove-Item $npmPath -Recurse -Force -ErrorAction Stop
                Write-LogSuccess "Removed npm installation directory: $npmPath"
                $removedNpm = $true
            }
            catch {
                Write-LogWarning "Could not remove npm directory: $npmPath"
                $failed = $true
            }
        }
    }
    
    if ($removedNpm) {
        Write-LogSuccess "NPM installation cleanup completed"
    }
    
    return (-not $failed)
}

function Remove-ClaudeDirectory {
    $expectedPath = Join-Path $env:USERPROFILE ".claude"
    if ($ClaudeDir -ne $expectedPath) {
        Write-LogError "Refusing to remove unexpected directory: $ClaudeDir"
        return $false
    }
    
    if (Test-Path $ClaudeDir) {
        $dirSize = "unknown size"
        try {
            $size = (Get-ChildItem $ClaudeDir -Recurse -ErrorAction SilentlyContinue | 
                     Measure-Object -Property Length -Sum).Sum
            if ($size -gt 1GB) {
                $dirSize = "{0:N2} GB" -f ($size / 1GB)
            }
            elseif ($size -gt 1MB) {
                $dirSize = "{0:N2} MB" -f ($size / 1MB)
            }
            else {
                $dirSize = "{0:N2} KB" -f ($size / 1KB)
            }
        }
        catch {
            # Ignore size calculation errors
        }
        
        if (-not $Force -and -not $Quiet) {
            Write-Host "This will remove the Claude directory: $ClaudeDir" -ForegroundColor Yellow
            Write-Host "Directory size: $dirSize" -ForegroundColor Yellow
            Write-Host "This includes configuration, cache, and downloaded files." -ForegroundColor Yellow
            $response = Read-Host "Are you sure you want to continue? [y/N]"
            if ($response -notmatch '^[yY]') {
                Write-LogInfo "Skipping Claude directory removal"
                return $true
            }
        }
        
        try {
            Remove-Item $ClaudeDir -Recurse -Force -ErrorAction Stop
            Write-LogSuccess "Removed Claude directory: $ClaudeDir ($dirSize)"
            return $true
        }
        catch {
            Write-LogError "Failed to remove Claude directory: $ClaudeDir - $_"
            return $false
        }
    }
    else {
        Write-LogInfo "Claude directory not found: $ClaudeDir"
        return $true
    }
}

function Remove-WindowsSpecificItems {
    $removedCount = 0
    
    # Remove from Windows Apps folder if present
    $windowsAppsPath = Join-Path $LocalAppData "Microsoft\WindowsApps\claude.exe"
    if (Test-Path $windowsAppsPath) {
        try {
            Remove-Item $windowsAppsPath -Force -ErrorAction Stop
            $removedCount++
            Write-LogSuccess "Removed Windows App: $windowsAppsPath"
        }
        catch {
            Write-LogWarning "Could not remove Windows App: $windowsAppsPath"
        }
    }
    
    # Remove Start Menu shortcuts
    $startMenuPaths = @(
        (Join-Path $AppData "Microsoft\Windows\Start Menu\Programs\Claude.lnk"),
        (Join-Path $AppData "Microsoft\Windows\Start Menu\Programs\Claude Code.lnk"),
        (Join-Path ([Environment]::GetFolderPath("CommonStartMenu")) "Programs\Claude.lnk"),
        (Join-Path ([Environment]::GetFolderPath("CommonStartMenu")) "Programs\Claude Code.lnk")
    )
    
    foreach ($shortcut in $startMenuPaths) {
        if (Test-Path $shortcut) {
            try {
                Remove-Item $shortcut -Force -ErrorAction Stop
                $removedCount++
                Write-LogSuccess "Removed Start Menu shortcut: $shortcut"
            }
            catch {
                Write-LogWarning "Could not remove shortcut: $shortcut"
            }
        }
    }
    
    # Remove Desktop shortcuts
    $desktopPaths = @(
        (Join-Path ([Environment]::GetFolderPath("Desktop")) "Claude.lnk"),
        (Join-Path ([Environment]::GetFolderPath("Desktop")) "Claude Code.lnk"),
        (Join-Path ([Environment]::GetFolderPath("CommonDesktopDirectory")) "Claude.lnk"),
        (Join-Path ([Environment]::GetFolderPath("CommonDesktopDirectory")) "Claude Code.lnk")
    )
    
    foreach ($shortcut in $desktopPaths) {
        if (Test-Path $shortcut) {
            try {
                Remove-Item $shortcut -Force -ErrorAction Stop
                $removedCount++
                Write-LogSuccess "Removed Desktop shortcut: $shortcut"
            }
            catch {
                Write-LogWarning "Could not remove shortcut: $shortcut"
            }
        }
    }
    
    # Check and clean PATH environment variable
    try {
        $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
        $claudePaths = @(
            (Join-Path $LocalAppData "Programs\Claude"),
            (Join-Path $LocalAppData "Claude"),
            (Join-Path $env:USERPROFILE ".local\bin")
        )
        
        $pathParts = $userPath -split ';' | Where-Object { $_ -ne '' }
        $newPathParts = $pathParts | Where-Object { 
            $part = $_
            -not ($claudePaths | Where-Object { $part -like "$_*" })
        }
        
        if ($pathParts.Count -ne $newPathParts.Count) {
            $newPath = $newPathParts -join ';'
            [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
            Write-LogSuccess "Cleaned Claude paths from user PATH environment variable"
            $removedCount++
        }
    }
    catch {
        Write-LogWarning "Could not clean PATH environment variable: $_"
    }
    
    if ($removedCount -gt 0) {
        Write-LogSuccess "Removed $removedCount Windows-specific item(s)"
    }
    
    return $true
}

function Remove-RegistryEntries {
    $removedCount = 0
    
    $registryPaths = @(
        "HKCU:\Software\Claude",
        "HKCU:\Software\Anthropic",
        "HKCU:\Software\Anthropic\Claude Code",
        "HKLM:\Software\Claude",
        "HKLM:\Software\Anthropic",
        "HKLM:\Software\Anthropic\Claude Code"
    )
    
    foreach ($regPath in $registryPaths) {
        if (Test-Path $regPath) {
            try {
                Remove-Item $regPath -Recurse -Force -ErrorAction Stop
                $removedCount++
                Write-LogSuccess "Removed registry key: $regPath"
            }
            catch {
                Write-LogWarning "Could not remove registry key: $regPath - $_"
            }
        }
    }
    
    # Check uninstall registry entries
    $uninstallPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    
    foreach ($uninstallPath in $uninstallPaths) {
        if (Test-Path $uninstallPath) {
            try {
                Get-ChildItem $uninstallPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $displayName = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName
                    if ($displayName -match "Claude") {
                        try {
                            Remove-Item $_.PSPath -Recurse -Force -ErrorAction Stop
                            $removedCount++
                            Write-LogSuccess "Removed uninstall registry entry: $($_.PSPath)"
                        }
                        catch {
                            Write-LogWarning "Could not remove uninstall entry: $($_.PSPath)"
                        }
                    }
                }
            }
            catch {
                # Ignore errors enumerating registry
            }
        }
    }
    
    if ($removedCount -gt 0) {
        Write-LogSuccess "Removed $removedCount registry entries"
    }
    
    return $true
}

function Remove-WingetInstallation {
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        try {
            $wingetList = & winget list --id Anthropic.Claude 2>$null
            if ($LASTEXITCODE -eq 0 -and $wingetList -match "Claude") {
                Write-LogInfo "Found winget installation, attempting to uninstall..."
                try {
                    & winget uninstall --id Anthropic.Claude --silent 2>$null
                    Write-LogSuccess "Removed Claude via winget"
                    return $true
                }
                catch {
                    Write-LogWarning "Failed to remove Claude via winget"
                    return $false
                }
            }
        }
        catch {
            # winget list failed, package probably not installed
        }
    }
    
    return $true
}

function Main {
    $exitCode = 0
    
    Write-LogInfo "Starting Claude Code uninstallation for $platform..."
    
    if (-not $Force -and -not $Quiet) {
        Write-Host "This will completely remove Claude Code from your system." -ForegroundColor Yellow
        Write-Host "This includes:" -ForegroundColor Yellow
        Write-Host "  - Claude binary files" -ForegroundColor Yellow
        Write-Host "  - PowerShell profile integration" -ForegroundColor Yellow
        Write-Host "  - Configuration and cache files" -ForegroundColor Yellow
        Write-Host "  - Registry entries" -ForegroundColor Yellow
        Write-Host ""
        $response = Read-Host "Do you want to continue? [y/N]"
        if ($response -notmatch '^[yY]') {
            Write-LogInfo "Uninstallation cancelled"
            exit 0
        }
    }
    
    # Try built-in uninstall first
    if (-not (Invoke-ClaudeUninstall)) {
        Write-LogInfo "Performing manual cleanup..."
        
        Remove-ProfileIntegration
        
        if (-not (Remove-Binaries)) {
            $exitCode = 1
        }
        
        if (-not (Remove-NpmInstallation)) {
            $exitCode = 1
        }
        
        if (-not (Remove-WingetInstallation)) {
            $exitCode = 1
        }
    }
    
    # Always try to remove Windows-specific items
    if (-not (Remove-WindowsSpecificItems)) {
        $exitCode = 1
    }
    
    # Always try to remove registry entries
    if (-not (Remove-RegistryEntries)) {
        $exitCode = 1
    }
    
    # Always try to remove the Claude directory
    if (-not (Remove-ClaudeDirectory)) {
        $exitCode = 1
    }
    
    if ($exitCode -eq 0) {
        Write-LogSuccess "Claude Code uninstallation complete!"
    }
    else {
        Write-LogWarning "Claude Code uninstallation completed with some issues"
    }
    
    Write-Host ""
    Write-Host "Claude Code has been successfully removed from your system." -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: You may need to restart your PowerShell session or run:" -ForegroundColor Blue
    Write-Host "  . `$PROFILE" -ForegroundColor Blue
    Write-Host "to remove claude from your current session." -ForegroundColor Blue
    
    # Check if claude is still accessible
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudeCmd) {
        Write-Host ""
        Write-LogWarning "Claude command is still accessible in PATH. You may need to:"
        Write-LogWarning "1. Restart your terminal/PowerShell"
        Write-LogWarning "2. Check for additional installations"
        Write-LogWarning "3. Manually remove remaining files"
        $exitCode = 1
    }
    
    exit $exitCode
}

# Handle interrupts
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-LogError "Uninstallation interrupted"
}

try {
    Main
}
catch {
    Write-LogError "Uninstallation failed: $_"
    exit 1
}
