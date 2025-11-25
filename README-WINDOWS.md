# Claude Code Uninstaller

## Usage

```powershell
& .\cc-uninstall.ps1
```

**Options:**
- `-Force` - Skip prompts
- `-Quiet` - Silent mode (implies -Force, perfect for scripts)
- `-Help` - Show help

**Examples:**
```powershell
# Interactive (asks before removing $env:USERPROFILE\.claude)
& .\cc-uninstall.ps1

# Automation/CI-CD
& .\cc-uninstall.ps1 -Quiet
```

## What Gets Removed

- **Binaries**: `%LOCALAPPDATA%\Programs\Claude\claude.exe`, `%USERPROFILE%\.local\bin\claude.exe`, etc.
- **NPM packages**: Global installations and broken leftovers
- **PowerShell profiles**: Removes Claude lines from PowerShell profile files (creates backups)
- **Registry entries**: Windows registry keys for Claude/Anthropic
- **Shortcuts**: Start Menu and Desktop shortcuts
- **Data directory**: `%USERPROFILE%\.claude` (prompts unless -Force)

## Safety Features

**PowerShell profile backups**: Before modifying any profile file, creates timestamped backups:
```powershell
$PROFILE.claude-backup.20250904-143022
```

**Path validation**: Only removes the expected `%USERPROFILE%\.claude` directory, refuses to delete unexpected paths.

**Binary safety**: Only removes files ending with `\claude.exe` or Claude-related registry entries.

**Exit codes**: Returns 0 on success, non-zero if any major operation failed (good for CI/CD).

## NPM-Only Users

Just use npm's official command:
```bash
npm uninstall -g @anthropic-ai/claude-code
```

But if that fails with ENOTEMPTY errors (common), run this script instead.

## Troubleshooting

**"Could not remove" warnings:**
```powershell
# Script shows exact commands to run
Remove-Item -Force "$env:USERPROFILE\.local\bin\claude.exe"
```

**Claude still in PATH after uninstall:**
1. Restart PowerShell/terminal
2. Run `powershell -ExecutionPolicy Bypass -File cc-uninstall.ps1 -Force` again

**For automation:**
Script returns exit code 0 on success, non-zero if issues occurred.

## Platform Support

- Windows (No WSL - native installer)
- Windows (No WSL - npm installer)
- Windows via WSL
