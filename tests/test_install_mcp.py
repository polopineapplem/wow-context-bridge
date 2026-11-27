"""Mock tests for install-mcp.ps1 using temporary config files. Never touches real client configs.

Run: python tests/test_install_mcp.py   (set PWSH=/path/to/pwsh if needed)
"""
import json, os, pathlib, shutil, subprocess, tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PWSH = os.environ.get('PWSH') or shutil.which('pwsh') or shutil.which('powershell.exe')
assert PWSH, 'PowerShell not found; set PWSH'
tmp = pathlib.Path(tempfile.mkdtemp(prefix='lcb-install-'))
claude = tmp / 'Claude' / 'claude_desktop_config.json'
codex = tmp / '.codex' / 'config.toml'


def run(*extra):
    p = subprocess.run([PWSH, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(ROOT / 'install-mcp.ps1'),
                        '-ClaudeConfigPath', str(claude), '-CodexConfigPath', str(codex), *extra],
                       capture_output=True, timeout=60)
    assert p.returncode == 0, p.stderr.decode('utf-8', 'replace')
    return p.stdout.decode('utf-8', 'replace')


def check(cond, label):
    if not cond:
        raise AssertionError(label)
    print('PASS', label)


claude.parent.mkdir(parents=True)
claude.write_text(json.dumps({'mcpServers': {'other': {'command': 'x', 'args': ['a']}}, 'globalShortcut': 'Ctrl+Space'}), encoding='utf-8')
codex.parent.mkdir(parents=True)
codex.write_text('model = "gpt-5"\n\n[mcp_servers.other]\ncommand = "y"\n', encoding='utf-8')

out = run('-DryRun')
check('would write' in out and 'wow-context' not in claude.read_text(), 'dry run changes nothing')

run()
cfg = json.loads(claude.read_text(encoding='utf-8'))
srv = cfg['mcpServers']['wow-context']
check(srv['args'][-1].endswith('mcp-server.ps1') and srv['args'][:4] == ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File'], 'Claude entry points at this checkout')
check(cfg['mcpServers']['other']['command'] == 'x' and cfg['globalShortcut'] == 'Ctrl+Space', 'other Claude settings preserved')
check(isinstance(srv['args'], list) and isinstance(cfg['mcpServers']['other']['args'], list), 'arrays stay arrays (PowerShell 5.1 Count/value bug guarded)')
toml = codex.read_text(encoding='utf-8')
check('model = "gpt-5"' in toml and '[mcp_servers.other]' in toml, 'other Codex settings preserved')
check(toml.count('[mcp_servers.wow-context]') == 1 and 'mcp-server.ps1' in toml, 'Codex entry added')
check(len(list(claude.parent.glob('*.bak'))) == 1 and len(list(codex.parent.glob('*.bak'))) == 1, 'backups written')

run()
check(codex.read_text(encoding='utf-8').count('[mcp_servers.wow-context]') == 1 and len(json.loads(claude.read_text())['mcpServers']) == 2, 'rerun is idempotent')

# Whole file must still be valid TOML (parse with tomllib when available).
try:
    import tomllib
    data = tomllib.loads(codex.read_text(encoding='utf-8'))
    check(data['mcp_servers']['wow-context']['args'][-1].endswith('mcp-server.ps1') and data['mcp_servers']['other']['command'] == 'y', 'config.toml parses as valid TOML')
except ModuleNotFoundError:
    print('SKIP TOML parse (Python < 3.11)')

run('-Uninstall')
check('wow-context' not in json.loads(claude.read_text())['mcpServers'] and 'other' in json.loads(claude.read_text())['mcpServers'], 'uninstall removes only our Claude entry')
toml = codex.read_text(encoding='utf-8')
check('wow-context' not in toml and '[mcp_servers.other]' in toml, 'uninstall removes only our Codex entry')

shutil.rmtree(claude.parent); shutil.rmtree(codex.parent)
run()
check(json.loads(claude.read_text())['mcpServers']['wow-context'] and codex.exists() is True, 'fresh install creates configs when folders exist or are given')
print('Fixture tests only; real client configs were not touched.')
shutil.rmtree(tmp)
