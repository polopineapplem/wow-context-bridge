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
questLog={{isHeader=true,title='贫瘠之地',questID=0},{questID=123,title='北方城堡的火炮',level=21,suggestedGroup=0},
  {isHeader=true,title='副本',questID=0},{questID=124,title='长任务',level=24,suggestedGroup=5}}
questTexts={[2]='把3枚徽章交给十字路口的某人。',[4]=string.rep('很长',400)}
selected=7; textCalls=0
C_QuestLog={GetNumQuestLogEntries=function() return #questLog end,GetInfo=function(i) return questLog[i] end,
GetQuestObjectives=function() return {{text='徽章：3/10',finished=false,numFulfilled=3,numRequired=10}} end,
IsComplete=function() return false end,GetAllCompletedQuestIDs=function() return {1,2,3} end,
GetQuestsOnMap=function(map) return {{questID=123,x=0.4,y=0.6}} end}
function GetQuestLogSelection() return selected end
function SelectQuestLogEntry(i) selected=i end
function GetQuestLogQuestText() textCalls=textCalls+1; return 'desc',questTexts[selected] end
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
q1,q2=s['quests']
assert q1['header']=='贫瘠之地' and q2['header']=='副本', 'quest log header (zone/category) from the client'
assert q1['level']==21 and 'suggestedGroup' not in q1 and q2['suggestedGroup']==5
assert q1['objectivesText']=='把3枚徽章交给十字路口的某人。'
assert len(q2['objectivesText'].encode('utf-8'))<=600, 'long text truncated on a UTF-8 boundary (payload decoded fine)'
assert q1['poi']=={'mapID':1413,'x':40,'y':60} and 'poi' not in q2
assert lua.globals().selected==7, 'quest log selection restored'
assert s['api']['GetQuestLogQuestText'] is True and s['api']['C_QuestLog.GetNextWaypoint'] is False
calls=lua.globals().textCalls
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
assert lua.globals().textCalls==calls, 'quest text cached per quest ID (read once)'
# A client without the optional quest APIs still exports quests, just without the extra fields.
lua.execute('GetQuestLogQuestText=nil;SelectQuestLogEntry=nil;GetQuestLogSelection=nil;C_QuestLog.GetQuestsOnMap=nil')
lua.execute('lines={};tick();drain()')
s=json.loads(bytes.fromhex(''.join(x.split(' ')[-1] for x in lua.globals().lines.values() if x.startswith('LCB1 '))))
assert s['capabilities']['quests'] is True and len(s['quests'])==2 and 'poi' not in s['quests'][0]
assert s['quests'][0]['objectivesText']  # cached from before; new quests would simply lack it
assert s['api']['GetQuestLogQuestText'] is False
print('PASS Lua 5.1 actual addon execution with mock APIs: Chinese, equipment, quests, coordinates, combat suppression, unsupported API isolation')
print('PASS Forever quest fields: header, level, suggestedGroup, objectivesText (cached, UTF-8 safe, selection restored), poi, api probe')
