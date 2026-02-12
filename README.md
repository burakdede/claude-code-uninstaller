# Claude Code Uninstaller

**[PowerShell Version Available](README-WINDOWS.md)** - If you're on Windows without WSL or other bash support, there is a PowerShell version.

Anthropic's native binary installation (currently in beta) doesn't provide an uninstall method. This script removes both npm and native binary installations completely.

**Anthropic now provides [official uninstall instructions](https://code.claude.com/docs/en/setup#uninstall-claude-code).** As of 2026‑01‑06 you can follow their guide directly, but this script remains available if you prefer a single command that cleans up every installation source and makes backups for you.

## Usage

### Why this exists

Mixed npm/native installs used to leave stray binaries, shell completions, and caches that interfered with new releases. This script gives you a clean slate by removing every known Claude Code path (with backups) in one pass, which was especially important before Anthropic shipped an official uninstall flow.

### Quick install (recommended)

```bash
chmod +x install.sh
./install.sh            # installs to ~/.local/bin/cc-uninstall by default
cc-uninstall --help
```

**Verification:**
```bash
command -v cc-uninstall   # should print ~/.local/bin/cc-uninstall
cc-uninstall --help       # shows usage banner
```

### Run directly

```bash
chmod +x cc-uninstall.sh
./cc-uninstall.sh
```

**Options:**
- `--force` - Skip prompts
- `--quiet` - Silent mode (implies --force, perfect for scripts)
- `--help` - Show help

**Examples:**
```bash
# Interactive (asks before removing ~/.claude)
./cc-uninstall.sh

# Automation/CI-CD
./cc-uninstall.sh --quiet
```

## What Gets Removed

- **Binaries**: `~/.local/bin/claude`, `/usr/local/bin/claude`, etc.
- **Data cache**: `~/.local/share/claude`
- **NPM packages**: Global installations and broken leftovers
- **Shell configs**: Removes Claude lines from `.bashrc`, `.zshrc`, etc. (creates backups)
- **User settings**: `~/.claude`, `~/.claude.json`
- **Project settings**: `.claude/` directory and `.mcp.json` in the directory where you run the script

## Safety Features

**Shell config backups**: Before modifying any shell config file, creates timestamped backups:
```bash
~/.zshrc.claude-backup.20250904-143022
```

**Automatic asset backups**: Every directory/file deleted by the script (`~/.claude`, `~/.local/share/claude`, `~/.claude.json`, project `.claude/`, `.mcp.json`, npm installs, PATH binaries) is copied next to the original as `<name>.claude-backup.<timestamp>`. Restore by moving or copying that backup back into place, and you can confirm they exist with `ls <path>.claude-backup.*`.

**Path validation**: Only removes the expected `~/.claude` directory, refuses to delete unexpected paths.

**Binary safety**: Only removes files ending with `/claude` from PATH to prevent accidents.

**Exit codes**: Returns 0 on success, non-zero if any major operation failed (good for CI/CD).

## NPM-Only Users

Just use npm's official command:
```bash
npm uninstall -g @anthropic-ai/claude-code
```

But if that fails with ENOTEMPTY errors (common), run this script instead.

## Troubleshooting

**"Could not remove" warnings:**
```bash
# Script shows exact commands to run
sudo rm -f /usr/local/bin/claude
```

**Claude still in PATH after uninstall:**
1. Restart terminal
2. Run `./cc-uninstall.sh --force` again

## Platform Support

- macOS (Intel/Apple Silicon)
- Linux (x64/ARM, including Alpine/musl)
- Windows via WSL
- Windows (no WSL) - **[See PowerShell version](README-WINDOWS.md)**

## License

MIT License - see [LICENSE](LICENSE) file for details.

Use at your own risk. Script removes files and directories.
