-- Original implementation, MIT. Forever 1.60.1 only; no gameplay actions.
local sending, busy, active, seq = false, false, false, 0
local session = tostring(time()) .. "-" .. tostring(math.random(100000,999999))
local function quote(s)
  return '"' .. tostring(s):gsub('[%z\1-\31\\"]', function(c)
    return string.format('\\u%04x', string.byte(c))
  end) .. '"'
end
local function json(v)
  if type(v)=='string' then return quote(v) end
  if type(v)=='number' or type(v)=='boolean' then return tostring(v) end
  if type(v)~='table' then return 'null' end
  local parts={}
  if v._array then
    for i=1,#v do parts[#parts+1]=json(v[i]) end
    return '['..table.concat(parts,',')..']'
  end
  for k,x in pairs(v) do parts[#parts+1]=quote(k)..':'..json(x) end
  return '{'..table.concat(parts,',')..'}'
end
local function snapshot()
  local name,surname=UnitName('player')
  if surname and surname~='' then name=name..' '..surname end
  local class,token,classID=UnitClass('player')
  local race,_,raceID=UnitRace('player')
  local version,build,_,interface=GetBuildInfo()
  local s={schemaVersion=1,capturedAt=time(),session=session,sequence=seq,
    client={version=version,build=build,interface=interface,locale=GetLocale()},
    character={name=name,realm=GetRealmName(),class=class,classToken=token,classID=classID,race=race,raceID=raceID,level=UnitLevel('player')},
    quests={_array=true},equipment={_array=true},capabilities={},errors={_array=true}}
  local function read(key,fn)
    local ok,err=pcall(fn)
    s.capabilities[key]=ok
    if not ok then s.errors[#s.errors+1]={section=key,message=tostring(err)} end
  end
  read('quests',function()
    local collapsed=false
    for i=1,C_QuestLog.GetNumQuestLogEntries() do
      local q=C_QuestLog.GetInfo(i)
      if q and q.isHeader and q.isCollapsed then collapsed=true end
      if q and not q.isHeader and not q.isHidden and q.questID>0 then
        local objectives={_array=true}
        for _,o in ipairs(C_QuestLog.GetQuestObjectives(q.questID) or {}) do
          objectives[#objectives+1]={text=o.text,type=o.type,finished=o.finished,numFulfilled=o.numFulfilled,numRequired=o.numRequired}
        end
        s.quests[#s.quests+1]={id=q.questID,name=q.title,complete=C_QuestLog.IsComplete(q.questID),objectives=objectives}
      end
    end
    s.questLogMayBeIncomplete=collapsed
  end)
  read('completedQuests',function()
    local ids=C_QuestLog.GetAllCompletedQuestIDs()
    assert(type(ids)=='table','completed quest list unavailable')
    ids._array=true; s.completedQuestIDs=ids
  end)
  read('location',function()
    local map=C_Map.GetBestMapForUnit('player')
    local info=map and C_Map.GetMapInfo(map)
    local p=map and C_Map.GetPlayerMapPosition(map,'player')
    s.location={mapID=map,mapName=info and info.name,zone=GetZoneText(),subzone=GetSubZoneText(),coordinateUnit='percent',coordinatesAvailable=p~=nil,x=p and p.x*100,y=p and p.y*100}
  end)
  read('equipment',function()
    for slot=1,19 do
      local id=GetInventoryItemID('player',slot)
      local link=GetInventoryItemLink('player',slot)
      local itemName=link and link:match('%[(.-)%]')
      if id and not itemName and C_Item and C_Item.GetItemNameByID then itemName=C_Item.GetItemNameByID(id) end
      s.equipment[#s.equipment+1]={slot=slot,id=id,name=itemName,empty=id==nil,namePending=id~=nil and itemName==nil}
    end
  end)
  return s
end
local function send(line)
  sending=true
  local ok=pcall(SendSystemMessage,line)
  sending=false
  return ok
end
ChatFrame_AddMessageEventFilter('CHAT_MSG_SYSTEM',function() return sending end)
local function emit()
  if busy or not active or InCombatLockdown() then return end
  local _,_,_,interface=GetBuildInfo()
  if interface~=16001 then return end
  if not SendSystemMessage then return end
  local ok=pcall(LoggingChat,true)
  if not ok then return end
  seq=seq+1
  local success,data=pcall(snapshot)
  if not success then return end
  local hex=json(data):gsub('.',function(c) return string.format('%02x',string.byte(c)) end)
  local queue={}
  local n=math.ceil(#hex/700)
  for i=1,n do queue[#queue+1]='LCB1 '..session..' '..seq..' '..i..' '..n..' '..hex:sub((i-1)*700+1,i*700) end
  -- Bounded padding pushes the client's chat buffer to disk; spread over frames.
  for i=1,58 do queue[#queue+1]='LCB1PAD '..string.rep('z',900) end
  busy=true
  local i=1
  local function pump()
    if not active then busy=false; return end
    for _=1,2 do if queue[i] then send(queue[i]); i=i+1 end end
    if i<=#queue then C_Timer.After(0,pump) else busy=false end
  end
  pump()
end
local f=CreateFrame('Frame')
f:RegisterEvent('PLAYER_ENTERING_WORLD'); f:RegisterEvent('PLAYER_LEAVING_WORLD')
f:SetScript('OnEvent',function(_,event)
  active=event=='PLAYER_ENTERING_WORLD'
  if active then C_Timer.After(3,emit) end
end)
C_Timer.NewTicker(15,emit)
