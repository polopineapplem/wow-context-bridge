import pathlib, json, tempfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
from lupa.lua51 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
lines={}; timers={}; combat=false
function time() return 1795752000 end
function UnitName() return '亡灵','法师' end
function UnitClass() return '法师','MAGE',8 end
function UnitRace() return '亡灵','Scourge',5 end
function UnitLevel() return 22 end
function GetRealmName() return 'Forever' end
function GetBuildInfo() return '1.60.1','71139','',16001 end
function GetLocale() return 'zhCN' end
function GetZoneText() return '贫瘠之地' end
function GetSubZoneText() return '棘齿城' end
function InCombatLockdown() return combat end
function LoggingChat() return true end
function SendSystemMessage(s) lines[#lines+1]=s end
function ChatFrame_AddMessageEventFilter(_,fn) filter=fn end
function CreateFrame() return {RegisterEvent=function() end,SetScript=function(_,_,fn) event=fn end} end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end,NewTicker=function(_,fn) tick=fn end}
C_QuestLog={GetNumQuestLogEntries=function() return 1 end,GetInfo=function() return {questID=123,title='北方城堡的火炮'} end,
GetQuestObjectives=function() return {{text='徽章：3/10',finished=false,numFulfilled=3,numRequired=10}} end,
IsComplete=function() return false end,GetAllCompletedQuestIDs=function() return {1,2,3} end}
C_Map={GetBestMapForUnit=function() return 1413 end,GetMapInfo=function() return {name='贫瘠之地'} end,
GetPlayerMapPosition=function() return {x=0.5,y=0.3} end}
function GetInventoryItemID(_,slot) if slot==16 then return 456 end end
function GetInventoryItemLink(_,slot) if slot==16 then return '|Hitem:456|h[测试法杖]|h' end end
function drain() while #timers>0 do local f=table.remove(timers,1);f() end end
''')
lua.execute((ROOT / 'LocalContext' / 'LocalContext.lua').read_text('utf-8'))
lua.execute("event(nil,'PLAYER_ENTERING_WORLD');drain()")
lines=list(lua.globals().lines.values())
payload=''.join(x.split(' ')[-1] for x in lines if x.startswith('LCB1 '))
s=json.loads(bytes.fromhex(payload))
assert s['quests'][0]['name']=='北方城堡的火炮'
assert s['character']['name']=='亡灵 法师'
assert s['equipment'][15]['name']=='测试法杖'
assert s['completedQuestIDs']==[1,2,3]
assert s['location']['x']==50
# Transport output validated in memory; do not write over real player data.
lua.execute('lines={};combat=true;tick();drain()')
assert len(lua.globals().lines)==0
lua.execute('combat=false;C_QuestLog.GetAllCompletedQuestIDs=nil;tick();drain()')
lines=list(lua.globals().lines.values())
s=json.loads(bytes.fromhex(''.join(x.split(' ')[-1] for x in lines if x.startswith('LCB1 '))))
assert s['capabilities']['completedQuests'] is False and len(s['errors'])==1
assert s['character']['level']==22
print('PASS Lua 5.1 actual addon execution with mock APIs: Chinese, equipment, quests, coordinates, combat suppression, unsupported API isolation')
