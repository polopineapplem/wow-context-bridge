"""Mock tests for mcp-server.ps1 over stdio. Uses fixture files only; not a live game test.

Run: python tests/test_mcp.py   (set PWSH=/path/to/pwsh if pwsh/powershell.exe is not on PATH)
"""
import json, os, pathlib, shutil, subprocess, sys, tempfile, time
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[1]
SERVER = ROOT / 'mcp-server.ps1'
PWSH = os.environ.get('PWSH') or shutil.which('pwsh') or shutil.which('powershell.exe')
assert PWSH, 'PowerShell not found; set PWSH'


def run(player, requests, history=None):
    args = [PWSH, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', str(SERVER), '-PlayerPath', str(player)]
    if history:
        args += ['-HistoryPath', str(history)]
    stdin = ''.join(json.dumps(r, ensure_ascii=False) + '\n' for r in requests)
    p = subprocess.run(args, input=stdin.encode('utf-8'), capture_output=True, timeout=60)
    lines = [l for l in p.stdout.decode('utf-8').splitlines() if l.strip()]
    msgs = [json.loads(l) for l in lines]  # every stdout line must be valid JSON-RPC
    return {m.get('id'): m for m in msgs}


def call(i, name, args=None):
    return {'jsonrpc': '2.0', 'id': i, 'method': 'tools/call', 'params': {'name': name, 'arguments': args or {}}}


def payload(msg):
    assert not msg['result']['isError'], msg
    return json.loads(msg['result']['content'][0]['text'])


def check(cond, label):
    if not cond:
        raise AssertionError(label)
    print('PASS', label)


tmp = pathlib.Path(tempfile.mkdtemp(prefix='lcb-mcp-'))
snap = json.loads((ROOT / 'tests' / 'fixtures' / 'player-sample.json').read_text(encoding='utf-8-sig'))
now = int(time.time())
live = dict(snap, capturedAt=now, freshness=dict(snap['freshness'], checkedAt=datetime.now(timezone.utc).isoformat()))
player = tmp / 'player.json'
player.write_text(json.dumps(live, ensure_ascii=False), encoding='utf-8')
history = tmp / 'history.jsonl'
history.write_text(json.dumps({'capturedAt': now, 'location': {'zone': '贫瘠之地'}, 'changes': ['level 21 -> 22']}, ensure_ascii=False) + '\n', encoding='utf-8')

init = {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-06-18', 'capabilities': {}, 'clientInfo': {'name': 'test', 'version': '0'}}}
r = run(player, [init, {'jsonrpc': '2.0', 'method': 'notifications/initialized'},
                 {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
                 call(3, 'get_player_context'), call(4, 'get_quests', {'includeCompletedIds': True}),
                 call(5, 'get_equipment'), call(6, 'get_recent_changes', {'limit': 5}),
                 call(7, 'no_such_tool'), {'jsonrpc': '2.0', 'id': 8, 'method': 'ping'}], history)

check(r[1]['result']['protocolVersion'] == '2025-06-18' and r[1]['result']['capabilities']['tools'] is not None, 'initialize negotiates version and tools capability')
check(None not in r and len(r) == 8, 'notification gets no response; stdout is pure JSON-RPC')
names = sorted(t['name'] for t in r[2]['result']['tools'])
check(names == ['get_equipment', 'get_player_context', 'get_quests', 'get_recent_changes'], 'tools/list exposes the 4 read-only tools')
check(all(t['annotations']['readOnlyHint'] for t in r[2]['result']['tools']), 'all tools marked readOnlyHint')
ctx = payload(r[3])
check(ctx['character']['name'] == snap['character']['name'] and ctx['character']['level'] == snap['character']['level'], 'context returns Chinese character name and level')
check(ctx['freshness']['stale'] is False and ctx['freshness']['readerLikelyRunning'] and ctx['freshness']['summary'] == 'live', 'fresh data reported live')
check(ctx['questCount'] == len(snap['quests']) and ctx['questLogMayBeIncomplete'] is True, 'quest count and incomplete flag passed through')
check(ctx['recentChanges'][0]['changes'] == ['level 21 -> 22'], 'recent changes included')
worn = [e for e in snap['equipment'] if e.get('id')]
check(len(ctx['equipment']) == len(worn) and all(isinstance(e['name'], str) and isinstance(e['id'], int) for e in ctx['equipment']), 'context equipment is one entry per worn item')
check(len(payload(r[4])['completedQuestIDs']) == len(snap['completedQuestIDs']), 'get_quests can include completed IDs')
eq = payload(r[5])['equipment']
check(len(eq) == 19 and any(e['slotName'] == 'mainHand' and e['id'] for e in eq), 'equipment has slot names')
check(len(payload(r[6])['changes']) == 1, 'get_recent_changes reads history')
check(r[7]['error']['code'] == -32602, 'unknown tool is an error')
check(r[8]['result'] == {}, 'ping')

# Historical snapshot: must be stale and reader reported as not running, never "live".
player.write_text(json.dumps(snap, ensure_ascii=False), encoding='utf-8')
ctx = payload(run(player, [init, call(2, 'get_player_context')])[2])
check(ctx['freshness']['stale'] is True and ctx['freshness']['readerLikelyRunning'] is False, 'historical snapshot reported stale, reader not running')

# Missing file and waiting state.
ctx = payload(run(tmp / 'missing.json', [init, call(2, 'get_player_context')])[2])
check(ctx['status'] == 'no_data', 'missing player.json reported as no_data')
player.write_text(json.dumps({'schemaVersion': 1, 'status': 'waiting_for_game', 'freshness': {'checkedAt': datetime.now(timezone.utc).isoformat()}}), encoding='utf-8')
ctx = payload(run(player, [init, call(2, 'get_player_context')])[2])
check(ctx['status'] == 'waiting_for_game' and ctx['freshness']['readerLikelyRunning'], 'waiting state passed through without fabricated character')
# Advisor prompt (docs/ADVISOR.md)
r = run(player, [init, {'jsonrpc': '2.0', 'id': 2, 'method': 'prompts/list'},
                 {'jsonrpc': '2.0', 'id': 3, 'method': 'prompts/get', 'params': {'name': 'what_next', 'arguments': {'focus': '升级'}}},
                 {'jsonrpc': '2.0', 'id': 4, 'method': 'prompts/get', 'params': {'name': 'nope'}}])
check(r[1]['result']['capabilities'].get('prompts') is not None, 'initialize advertises prompts')
check([p['name'] for p in r[2]['result']['prompts']] == ['what_next'], 'prompts/list has what_next')
text = r[3]['result']['messages'][0]['content']['text']
check('get_player_context' in text and '游戏顾问' in text and 'prompt:start' not in text and text.endswith('Focus on: 升级'), 'what_next returns ADVISOR.md body in Chinese plus focus')
check(r[4]['error']['code'] == -32602, 'unknown prompt is an error')
# Forever-native quest details (addon 0.2.0, D19) pass through; old snapshots without them still work.
rich = json.loads(json.dumps(live))
rich['quests'][0].update(header='贫瘠之地', level=21, suggestedGroup=5, objectivesText='把皮革交给某人。', poi={'mapID': 1413, 'x': 40.0, 'y': 60.0})
rich['api'] = {'GetQuestLogQuestText': True, 'C_QuestLog.GetNextWaypoint': False}
player.write_text(json.dumps(rich, ensure_ascii=False), encoding='utf-8')
r = run(player, [init, call(2, 'get_player_context')], history)
q0, q1 = payload(r[2])['quests'][:2]
check(q0['header'] == '贫瘠之地' and q0['level'] == 21 and q0['suggestedGroup'] == 5 and q0['objectivesText'] == '把皮革交给某人。' and q0['poi']['x'] == 40.0, 'context passes Forever quest details through')
check('header' not in q1 and 'objectivesText' not in q1 and payload(r[2])['questApi']['GetQuestLogQuestText'] is True, 'missing details stay absent; API probe exposed')

print('Fixture tests only; not a live game test.')
shutil.rmtree(tmp)
