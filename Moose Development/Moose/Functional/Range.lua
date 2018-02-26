-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- **Functional** - RANGE
--  
-- ![Banner Image](..\Presentations\RAT\RAT.png)
-- 
-- ====
-- 
-- Range practice.
-- 
-- ## Features
-- 
-- * Bla 1
-- * Bla 2  
-- 
-- ====
-- 
-- # Demo Missions
--
-- ### [ALL Demo Missions pack of the last release](https://github.com/FlightControl-Master/MOOSE_MISSIONS/releases)
-- 
-- ====
-- 
-- # YouTube Channel
-- 
-- ### [MOOSE YouTube Channel](https://www.youtube.com/playlist?list=PL7ZUrU4zZUl1jirWIo4t4YxqN-HxjqRkL)
-- 
-- ===
-- 
-- ### Author: **[funkyfranky](https://forums.eagle.ru/member.php?u=115026)**
-- 
-- ### Contributions: **Sven van de Velde ([FlightControl](https://forums.eagle.ru/member.php?u=89536))**
-- 
-- ====
-- @module Range

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- RANGE class
-- @type RANGE
-- @field #string ClassName Name of the Class.
-- @field #boolean Debug If true, print debug info to dcs.log file.
-- @field #table strafeTargets Table of strafing targets.
-- @field #table bombingTargets Table of targets to bomb.
-- @field #table addTo Table.
-- @field #table strafeStatus Table.
-- @field #table strafePlayerResults Table.
-- @field #table bombPlayerResults Table.
-- @field #table planes Table.
-- @extends Core.Base#BASE

---# RANGE class, extends @{Base#BASE}
-- The RANGE class
-- 
--
-- ## Usage
-- 
-- ![Process](..\Presentations\RAT\RAT_Airport_Selection.png)
-- 
-- ### Coding:
-- 
-- * Simply write PSEUDOATC:New() anywhere into your script.
-- 
-- 
-- @field #RANGE
RANGE={
  ClassName = "RANGE",
  Debug=true,
  strafeTargets={},
  bombingTargets={},
  addedTo = {},
  strafeStatus = {},
  strafePlayerResults = {},
  bombPlayerResults = {},
  planes = {},
}

--- RANGE contructor.
-- @param #RANGE self
-- @return #RANGE Returns a RANGE object.
function RANGE:New()

  -- Inherit BASE.
  local self=BASE:Inherit(self, BASE:New()) -- #RANGE
  
  -- Debug info
  --TODO: add
  --env.info(RANGE.id..string.format("Creating RANGE object. RANGE version %s", RANGE.version.version))
  
  -- Return object.
  return self
end

--- Add a unit as strafe target. For a strafe target hits from guns are counted. 
-- @param #RANGE self
-- @param Wrapper.Unit#UNIT unit Unit of the strafe target.
-- @param #number boxlength (Optional) Length of the approach box in meters. Default is 3000 m.
-- @param #number boxwidth (Optional) Width of the approach box in meters. Default is 1000 m.
-- @param #number heading (Optional) Approach heading in Degrees. Default is heading of the unit as defined in the mission editor.
-- @param #boolean inverseheading (Optional) Take inverse heading (heading --> heading - 180 Degrees). Default is false.
-- @param #number foulelinedistance (Optional) Foule line distance. Hits from closer of this distance are not counted.
function RANGE:AddStrafeTargetUnit(unit, boxlength, boxwidth, heading, inverseheading, foulelinedistance)
  
  -- heading
  local heading=heading or unit:GetHeading()
  
  if inverseheading ~= nil then
    if inverseheading then
      heading=heading-180
    end
  end
  
  local center=unit:GetCoordinate()
  local l=boxlength or 3000
  local w=(boxwidth or 1000)/2

  -- Points defining the approach area.  
  local p={}
  p[1]=center
  p[2]=p[1]:Translate(  w, heading+90)
  p[3]=p[2]:Translate(  l, heading)
  p[4]=p[3]:Translate(2*w, heading-90)
  p[5]=p[4]:Translate( -l, heading)
  
  -- Smoke points.
  for _,point in pairs(p) do
    point=point --Core.Point#COORDINATE
    point:SmokeRed()
  end

  -- Create zone.
  local zonename="Zone_"..unit:GetName()
  local zonepolygon=ZONE_POLYGON_BASE:New(zonename, p)
  
  -- Add zone to table.
  table.insert(self.strafeTargets, {name=zonename, polygon=zonepolygon})
  
end

--- Start RANGE training.
-- @param #RANGE self
function RANGE:Start()

  -- event handler
  world.addEventHandler(self)

--[[
  for _,_targetZone in pairs(self.strafeTargets) do
  
    if Group.getByName(_targetZone.name) then
    
      --TODO: Get MOOSE points.
      local _points = mist.getGroupPoints(_targetZone.name)
  
      env.info("Done for: ".._targetZone.name)
      _targetZone.polygon = _points
    else
      env.info("Couldn't find: ".._targetZone.name)
      _targetZone.polygon = nil
    end
  
  end
]]  

--[[  
  local _tempTargets = self.bombingTargets
  
  self.bombingTargets = {}
  
  for _,_targetZone in pairs(_tempTargets) do
  
    local _triggerZone = trigger.misc.getZone(_targetZone)
  
    if _triggerZone then
      table.insert(self.bombingTargets,{name=_targetZone,point=_triggerZone.point})
      env.info("Done for: ".._targetZone)
    else
      env.info("Failed for: ".._targetZone)
    end
  
  end
]]

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Range event handler.
-- @param #RANGE self
-- @param #table _event DCS event.
-- @return #boolean
function RANGE:onEvent(_event)
  env.info("Range event: ", table.concat(_event, ", "))
  if _event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
    env.info("Range event: Player entered unit! Player name = "..tostring(_event.initiator:getPlayerName()))
  elseif _event.id == world.event.S_EVENT_BIRTH then
    env.info("Range event: Birth! Player name = "..tostring(_event.initiator:getPlayerName()))
  end

  if _event == nil or _event.initiator == nil then
    return true
  end


  if _event.id == 15 then --player entered unit, FF: id=15 is actually birth.

    -- env.info("Player entered unit")
    if  _event.initiator:getPlayerName() then
    
      local id=_event.initiator:getID()
      local name=_event.initiator:getName()
  
      -- reset current status
      self.strafeStatus[id] = nil
  
      self:addF10Commands(name)
  
      if self.planes[id] ~= true then
  
          self.planes[id] = true
  
          self:checkInZone(name)
      end
  
    end
  end
  
  if  _event.id == world.event.S_EVENT_HIT and _event.target  then

    --env.info("HIT! ".._event.target:getName().." with ".._event.weapon:getTypeName())
    --_event.weapon is currently broken for clients
    --env.info(_event.initiator:getPlayerName().."HIT! ".._event.target:getName().." with ".._event.weapon:getTypeName())
    --trigger.action.outText("HIT! ".._event.target:getName().." with ".._event.weapon:getTypeName(),10,false)
    
    local _currentTarget = self.strafeStatus[_event.initiator:getID()]
  
    if _currentTarget then

      for _, _targetName in pairs(_currentTarget.zone.targets) do
        if _targetName == _event.target:getName() then
          _currentTarget.hits =  _currentTarget.hits + 1
          --TODO: this is for the pcall...
          return true 
        end
      end
      
    end
    
  end


  if _event.id == world.event.S_EVENT_SHOT then

    local _weapon = _event.weapon:getTypeName()
    local _weaponStrArray = self:split(_weapon,"%.")
  
    local _weaponName = _weaponStrArray[#_weaponStrArray]
    
    -- Altitude of player. Should be greater than min alt.
    local alt=_event.initiator:getPosition().p.y
    
    if (string.match(_weapon, "weapons.bombs") or string.match(_weapon, "weapons.nurs")) then

      local _ordnance =  _event.weapon
  
      env.info("Tracking ".._weapon.." - ".._ordnance:getName())
      local _lastBombPos = {x=0,y=0,z=0}

      local _unitName = _event.initiator:getName()
      
      -- Function monitoring the position of a bomb until impact.
      local function trackBomb(_previousPos)

        local _unit = Unit.getByName(_unitName)
  
        -- env.info("Checking...")
        if _unit ~= nil and _unit:getPlayerName() ~= nil then
  
          -- when the pcall returns a failure the weapon has hit
          local _status,_bombPos =  pcall(
          function()
            -- env.info("protected")
            return _ordnance:getPoint()
          end)
  
          if _status then
            --ok! still in the air
            _lastBombPos = {x = _bombPos.x, y = _bombPos.y, z= _bombPos.z }
    
            return timer.getTime() + 0.005 -- check again !
          else
          
            --hit
            -- get closet target to last position
            local _closetTarget = nil
            local _distance = nil
    
            for _,_targetZone in pairs(self.bombingTargets) do
    
              local _temp = self:getDistance(_targetZone.point, _lastBombPos)
    
              if _distance == nil or _temp < _distance then
    
                  _distance = _temp
                  _closetTarget = _targetZone
              end
            end
  
            --   env.info(_distance.." from ".._closetTarget.name)
    
            if _distance < 1000 then
    
              if not self.bombPlayerResults[_unit:getPlayerName()] then
                self.bombPlayerResults[_unit:getPlayerName()]  = {}
              end
    
              local _results =  self.bombPlayerResults[_unit:getPlayerName()]
  
              table.insert(_results,{name=_closetTarget.name, distance =_distance, weapon = _weaponName })
  
              local _message = string.format("%s - %i m from bullseye of %s", _unit:getPlayerName(), _distance,_closetTarget.name)
  
              trigger.action.outText(_message, 10, false)
            end
    
          end -- _status
            
        end -- end unit ~= nil
        
        return  --Terminate the timer (maybe better return nil?)
      end -- end function bombtrack

      timer.scheduleFunction(trackBomb, nil, timer.getTime() + 1)
      
    end --if string.match

  end


  --if (not status) then
  --    env.error(string.format("Error while handling event %s", err),false)
  --end

end

--------------------------------------
--

--- Display stafing results.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:displayMyStrafePitResults(_unitName)
  local _unit = Unit.getByName(_unitName)
  
  if _unit and _unit:getPlayerName() then
    local _message = "My Top 10 Strafe Pit Results: \n"
  
    local _results = self.strafePlayerResults[_unit:getPlayerName()]
  
    if _results == nil then
        _message = _unit:getPlayerName()..": No Score yet"
    else
  
      local _sort = function( a,b ) return a.hits > b.hits end
      table.sort(_results,_sort)
  
      local _bestMsg = ""
      local _count = 1
      for _,_result in pairs(_results) do
  
          _message = _message.."\n"..string.format("%s - Hits %i - %s",_result.zone.name,_result.hits,_result.text)
  
          if _bestMsg == "" then
  
              _bestMsg = string.format("%s - Hits %i - %s",_result.zone.name,_result.hits,_result.text)
          end
  
          -- 10 runs
          if _count == 10 then
              break
          end
  
          _count = _count+1
      end
  
      _message = _message .."\n\nBEST: ".._bestMsg
  
    end
  
    self:displayMessageToGroup(_unit, _message, 10, false)
  end

end

--- Display strafing results.
-- @param #RANGE self
-- @param #string _unitName Name fo the player unit.
function RANGE:displayStrafePitResults(_unitName)
  local _unit = Unit.getByName(_unitName)
  
  local _playerResults = {}
  if _unit and _unit:getPlayerName() then
  
    local _message = "Strafe Pit Results - Top 10:\n"
  
    for _playerName,_results in pairs(range.strafePlayerResults) do
  
      local _best = nil
      for _,_result in pairs(_results) do
  
        if _best == nil or _result.hits > _best.hits then
            _best = _result
        end
      end
  
      if _best ~= nil then
        table.insert(_playerResults,{msg = string.format("%s: %s - Hits %i - %s",_playerName,_best.zone.name,_best.hits,_best.text),hits = _best.hits})
      end
  
    end
  
    --sort list!
    local _sort = function( a,b ) return a.hits > b.hits end
    table.sort(_playerResults,_sort)
  
    for _i = 1, #_playerResults do
  
      _message = _message.."\n[".._i.."]".._playerResults[_i].msg
  
      --top 10
      if _i > 10 then
        break
      end
    end
  
    range.displayMessageToGroup(_unit, _message, 10,false)
  end

end

--- Reset statistics.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:resetRangeStats(_unitName)
  local _unit = Unit.getByName(_unitName)
  
  if _unit and _unit:getPlayerName() then
  
    self.strafePlayerResults[_unit:getPlayerName()] = nil
    self.bombingTargets[_unit:getPlayerName()] = nil
    self:displayMessageToGroup(_unit, "Range Stats Cleared", 10, false)
  end
end

--- Display player bombing results.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:displayMyBombingResults(_unitName)
  local _unit = Unit.getByName(_unitName)
  
  if _unit and _unit:getPlayerName() then
    local _message = "My Top 20 Bombing Results: \n"
  
    local _results = self.bombPlayerResults[_unit:getPlayerName()]
  
    if _results == nil then
      _message = _unit:getPlayerName()..": No Score yet"
    else
  
      local _sort = function( a,b ) return a.distance < b.distance end
  
      table.sort(_results,_sort)
  
      local _bestMsg = ""
      local _count = 1
      for _,_result in pairs(_results) do
  
        _message = _message.."\n"..string.format("%s - %s - %i m",_result.name,_result.weapon,_result.distance)
  
        if _bestMsg == "" then
  
            _bestMsg = string.format("%s - %s - %i m",_result.name,_result.weapon,_result.distance)
        end
  
        -- 20 runs
        if _count == 20 then
            break
        end
  
        _count = _count+1
      end
  
      _message = _message .."\n\nBEST: ".._bestMsg
  
    end
  
    self:displayMessageToGroup(_unit, _message, 10,false)
  end

end

--- Display all bombing results.
-- @param #RANGE self
-- @param #string _unitName Name of player unit.
function RANGE:displayBombingResults(_unitName)
  local _unit = Unit.getByName(_unitName)
  
  local _playerResults = {}
  if _unit and _unit:getPlayerName() then
  
    local _message = "Bombing Results - Top 15:\n"
  
    for _playerName,_results in pairs(self.bombPlayerResults) do
  
      local _best = nil
      for _,_result in pairs(_results) do
  
        if _best == nil or _result.distance < _best.distance then
            _best = _result
        end
      end
  
      if _best ~= nil then
        table.insert(_playerResults,{msg = string.format("%s: %s - %s - %i m",_playerName,_best.name,_best.weapon,_best.distance),distance = _best.distance})
      end
  
    end
  
    --sort list!
  
    local _sort = function( a,b ) return a.distance < b.distance end
  
    table.sort(_playerResults,_sort)
  
    for _i = 1, #_playerResults do
  
      _message = _message.."\n[".._i.."] ".._playerResults[_i].msg
  
      --top 15
      if _i > 15 then
        break
      end
    end
  
    self:displayMessageToGroup(_unit, _message, 10,false)
  end

end

-----------------------------------------------------------------
--

--- Check in zone.
-- @param #RANGE self
-- @param #string _unitName Name of player unit.
function RANGE:checkInZone(_unitName)

    --check if we're in any zone
    -- if we're in a zone, start looking for hits on target
    -- if we're no longer in a zone but were previously, list the result and store the run
    local _unit = Unit.getByName(_unitName)

    if _unit and _unit:getPlayerName() then

        --TODO: check syntax for timer with self or make MOOSE scheduler.
        timer.scheduleFunction(self.checkInZone, {self, _unitName}, timer.getTime() + 1)

        local _unitPos = _unit:getPosition().p
        local _unitCoord = COORDINATE:NewFromVec3(_unit:getPosition().p)
        
        local unit=UNIT:FindByName(_unitName)

        -- currently strafing?
        local _currentStrafeRun =  self.strafeStatus[_unit:getID()]

        if _currentStrafeRun ~= nil then
            --TODO: MOOSE polygon zone
            --if _currentStrafeRun.zone.polygon~=nil and mist.pointInPolygon(_unitPos,_currentStrafeRun.zone.polygon,_currentStrafeRun.zone.maxAlt) and _unitPos.y >= _currentStrafeRun.zone.minAlt then
            if _currentStrafeRun.zone.polygon~=nil and unit:IsInZone(_currentStrafeRun.zone.polygon) then
                --still in zone, do nothing
                _currentStrafeRun.time = _currentStrafeRun.time+1
            elseif _currentStrafeRun.zone.polygon~=nil then

                _currentStrafeRun.time = _currentStrafeRun.time+1

                if _currentStrafeRun.time <= 3 then
                    self.strafeStatus[_unit:getID()] = nil

                    local _msg = _unit:getPlayerName()..": left ".._currentStrafeRun.zone.."  too quickly. No Score. "
                    --TODO: Moose message.
                    self:displayMessageToGroup(_unit, _msg, 10, true)
                else
                    local _result = self.strafeStatus[_unit:getID()]

                    local _msg = _unit:getPlayerName().." "

                    if _result.hits >= _result.zone.goodPass then
                        _msg  = _msg .."GOOD PASS with ".._result.hits.." on "
                        _result.text = "GOOD PASS"
                    else
                        _msg  = _msg .."INEFFECTIVE PASS with ".._result.hits.." on "
                        _result.text = "INEFFECTIVE PASS"
                    end

                    _msg = _msg .._result.zone.name
                    -- TODO: Moose message.
                    trigger.action.outText(_msg,10,false)

                    self.strafeStatus[_unit:getID()] = nil

                    --  Save so the player can retrieve them
                    local _stats = self.strafePlayerResults[_unit:getPlayerName()] or {}

                    table.insert(_stats,_result)

                    self.strafePlayerResults[_unit:getPlayerName()] = _stats
                end

            end

        else
            -- check to see if we're in a zone
            for _,_targetZone in pairs(self.strafeTargets) do

                --TODO: MOOSE point in zone
                --if _targetZone.polygon~=nil and mist.pointInPolygon(_unitPos,_targetZone.polygon,_targetZone.maxAlt) then
                if unit:IsInZone(_targetZone.polygon) then

                    if  self.strafeStatus[_unit:getID()] == nil and _unitPos.y >= _targetZone.minAlt then

                        self.strafeStatus[_unit:getID()] = {hits = 0, zone = _targetZone, time = 1 }

                        local _msg = _unit:getPlayerName().." rolling in on ".._targetZone.name
                        -- TODO: MOOSE message.
                        self:displayMessageToGroup(_unit, _msg, 10,true)

                    end

                    break
                end
            end
        end
    else
        -- TODO: check self syntax or convert to MOOSE scheduler.
        timer.scheduleFunction(self.checkInZone, {self, _unitName}, timer.getTime() + 5)
    end
end

--- Get group id.
-- @param #RANGE self
-- @param DCS.unit#UNIT _unit DCS unit.
-- @return #number Group id.
function RANGE:getGroupId(_unit)

    --TODO: Convert to MOOSE
--    local _unitDB =  mist.DBs.unitsById[tonumber(_unit:getID())]
--    if _unitDB ~= nil and _unitDB.groupId then
--        return _unitDB.groupId
--    end
    
    local unit=UNIT:Find(_unit)
    if not unit then
      unit=CLIENT:Find(_unit)
    end
    local groupid=unit:GetGroup():GetID()
    if groupid then
      return groupid
    end

    return nil
end

--- Display message to group.
-- @param #RANGE self
-- @param DCS.unit#UNIT _unit Player unit.
-- @param #string _text Message text.
-- @param #number _time Duration how long the message is displayed.
-- @param #boolean _clear Clear up old messages.
function RANGE:displayMessageToGroup(_unit, _text, _time,_clear)

    local _groupId = range.getGroupId(_unit)
    if _groupId then
        if _clear == true then
            trigger.action.outTextForGroup(_groupId, _text, _time,_clear)
        else
            trigger.action.outTextForGroup(_groupId, _text, _time)
        end
    end
end


--- Add menu commands for player.
-- @param #RANGE self
-- @param #string _unitName Name of player unit.
function RANGE:addF10Commands(_unitName)

    local _unit = Unit.getByName(_unitName)
    if _unit then

        --TODO: convert to MOOSE.
        --local _group =  mist.DBs.unitsById[tonumber(_unit:getID())]
        local unit=UNIT:Find(_unit)
        local group=unit:GetGroup()
        local _gid=group:GetID()

        --if _group  then
        if group and _gid  then

          --local _gid =  _group.groupId
          if not self.addedTo[_gid] then
              self.addedTo[_gid] = true

              local _rootPath = missionCommands.addSubMenuForGroup(_gid, "Range")

              --TODO: Convert to MOOSE menu.
              missionCommands.addCommandForGroup(_gid, "My Strafe results", _rootPath, self.displayMyStrafePitResults, self, _unitName)
              missionCommands.addCommandForGroup(_gid, "All Strafe results", _rootPath, self.displayStrafePitResults, self, _unitName)
              missionCommands.addCommandForGroup(_gid, "My Bombing results", _rootPath, self.displayMyBombingResults, self, _unitName)
              missionCommands.addCommandForGroup(_gid, "All Bombing results", _rootPath, self.displayBombingResults, self, _unitName)
              missionCommands.addCommandForGroup(_gid, "Reset Stats", _rootPath, self.resetRangeStats, self, _unitName)
          end
        else
          env.info("RANGE: ERROR! Could not find group ID.")
        end
    end

end

--- Get distance in meters assuming a Flat world.
-- @param #RANGE self
-- @param Core.Point#COORDINATE _point1 First point.
-- @param Core.Point#COORDINATE _point2 Second point.
function RANGE:getDistance(_point1, _point2)

    local xUnit = _point1.x
    local yUnit = _point1.z
    local xZone = _point2.x
    local yZone = _point2.z

    local xDiff = xUnit - xZone
    local yDiff = yUnit - yZone

    return math.sqrt(xDiff * xDiff + yDiff * yDiff)
end

--- http://stackoverflow.com/questions/1426954/split-string-in-lua
-- @param #RANGE self
-- @param #string str Sting to split.
-- @param #string sep Speparator for split.
-- @return #table Split text.
function RANGE:split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do
        table.insert(result, each)
    end
    return result
end

----------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------