"""Mock tests for check-setup.ps1 and game-folder detection (lib/common.ps1), using a fake game folder.

Run: python tests/test_check_setup.py   (set PWSH=/path/to/pwsh if needed)
"""
import json, os, pathlib, shutil, subprocess, tempfile, time
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[1]
PWSH = os.environ.get('PWSH') or shutil.which('pwsh') or shutil.which('powershell.exe')
assert PWSH, 'PowerShell not found; set PWSH'
tmp = pathlib.Path(tempfile.mkdtemp(prefix='lcb-check-'))


def check(cond, label):
    if not cond:
        raise AssertionError(label)
    print('PASS', label)


def ps(command):
    env = dict(os.environ, WOW_CONTEXT_NO_SYSTEM_SEARCH='1')  # only the fake folders below
    p = subprocess.run([PWSH, '-NoProfile', '-Command', command], capture_output=True, timeout=60, env=env)
    return p.returncode, p.stdout.decode('utf-8', 'replace'), p.stderr.decode('utf-8', 'replace')


common = str(ROOT / 'lib' / 'common.ps1')

# ---------- game folder detection ----------
wow1 = tmp / 'D' / 'World of Warcraft'
(wow1 / '_forever_').mkdir(parents=True)
(wow1 / '_forever_' / 'Wow.exe').write_bytes(b'')
(wow1 / '_retail_').mkdir()
(wow1 / '_retail_' / 'Wow.exe').write_bytes(b'')  # not Forever, must be ignored
_, out, _ = ps(f". '{common}'; (Find-ForeverRoots @('{wow1}','{wow1}','{wow1 / '_forever_'}')) -join '|'")
check(out.strip() == str(wow1 / '_forever_'), 'finds _forever_ once, ignores _retail_ and duplicates')
_, out, _ = ps(f". '{common}'; Resolve-ForeverRoot '' @('{wow1}')")
check(out.strip() == str(wow1 / '_forever_'), 'single detected folder is used automatically')
wow2 = tmp / 'E' / 'World of Warcraft'
(wow2 / '_forever_').mkdir(parents=True)
(wow2 / '_forever_' / 'Wow.exe').write_bytes(b'')
code, out, err = ps(f". '{common}'; try {{ Resolve-ForeverRoot '' @('{wow1}','{wow2}') }} catch {{ 'ERR:' + $_.Exception.Message }}")
check('Several' in out and str(wow2 / '_forever_') in out, 'several folders: asks the user to choose with -GameRoot')
macwow = tmp / 'Applications' / 'World of Warcraft'
(macwow / '_forever_' / 'World of Warcraft.app' / 'Contents').mkdir(parents=True)
_, out, _ = ps(f". '{common}'; Resolve-ForeverRoot '' @('{macwow}')")
check(out.strip() == str(macwow / '_forever_'), 'macOS layout (World of Warcraft.app, no Wow.exe) is detected')
code, out, err = ps(f". '{common}'; try {{ Resolve-ForeverRoot '{tmp / 'nowhere'}' }} catch {{ 'ERR:' + $_.Exception.Message }}")
check(out.startswith('ERR:') and '_forever_' in out, 'wrong -GameRoot gives a clear error')

# ---------- check-setup ----------
game = wow1 / '_forever_'
claude = tmp / 'Claude' / 'claude_desktop_config.json'
codex = tmp / '.codex' / 'config.toml'
player = tmp / 'player.json'


def run_check():
    p = subprocess.run([PWSH, '-NoProfile', '-File', str(ROOT / 'check-setup.ps1'), '-GameRoot', str(game), '-PlayerPath', str(player),
                        '-ClaudeConfigPath', str(claude), '-CodexConfigPath', str(codex), '-Json'], capture_output=True, timeout=90)
    data = json.loads(p.stdout.decode('utf-8'))
    return p.returncode, {r['step']: r['status'] for r in data['results']}, data


code, st, _ = run_check()
check(code == 1 and st['game folder'] == 'PASS' and st['addon'] == 'FAIL' and st['reader'] == 'FAIL', 'empty setup: addon and reader reported missing, exit 1')
check(st['mcp server'] == 'PASS', 'mcp server smoke test passes')
check(st.get('ai client') == 'FAIL', 'no AI client configured is a failure')

addon = game / 'Interface' / 'AddOns' / 'LocalContext'
shutil.copytree(ROOT / 'LocalContext', addon)
(game / 'Logs').mkdir()
(game / 'Logs' / 'WoWChatLog.txt').write_text('11/27 10:00:00.000  LCB1 123-456 1 1 1 7b7d\n', encoding='utf-8')
snap = json.loads((ROOT / 'tests' / 'fixtures' / 'player-sample.json').read_text(encoding='utf-8-sig'))
snap.update(capturedAt=int(time.time()), status='snapshot_received', freshness={'checkedAt': datetime.now(timezone.utc).isoformat()})
player.write_text(json.dumps(snap, ensure_ascii=False), encoding='utf-8')
subprocess.run([PWSH, '-NoProfile', '-File', str(ROOT / 'install-mcp.ps1'), '-ClaudeConfigPath', str(claude), '-CodexConfigPath', str(codex)], capture_output=True, timeout=60, check=True)
code, st, data = run_check()
non_pass = {k: v for k, v in st.items() if v != 'PASS' and k != 'platform'}
check(code == 0 and not non_pass, f'complete setup passes every step (platform: {st["platform"]})')

(addon / 'LocalContext.lua').write_text('-- old version\n', encoding='utf-8')
code, st, _ = run_check()
check(st['addon'] == 'WARN', 'outdated installed addon is a warning')

snap['freshness'] = {'checkedAt': '2026-01-01T00:00:00+00:00'}
player.write_text(json.dumps(snap, ensure_ascii=False), encoding='utf-8')
code, st, _ = run_check()
check(code == 1 and st['reader'] == 'FAIL', 'stopped reader is a failure')
print('Fixture tests only; no real game or client config was touched.')
shutil.rmtree(tmp)
