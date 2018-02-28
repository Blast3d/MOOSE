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
-- @field #boolean bombimpactsmoke Smoke impact point of a bomb.
-- @field #boolean bombimpactflare Fire a flare at impact point of a bomb.
-- @field #boolean strafetargetflare F
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
  bombimpactsmoke=true,
  bombimpactflare=false,
  bombhitsmoke=true,
  strafetargetflare=true,
  strafehitsmoke=false,
}

--- Some ID to identify who we are in output of the DCS.log file.
-- @field #string id
RANGE.id="RANGE | "

--- Range script version.
-- @field #number id
--RANGE.version=0.1.0

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
-- @param #number goodpass (Optional) Number of hits for a "good" strafing pass. Default is 20.
-- @param #number foulline (Optional) Foul line distance. Hits from closer than this distance are not counted. Default 0. Realistic 610 m = 2000 ft.
function RANGE:AddStrafeTargetUnit(unit, boxlength, boxwidth, heading, inverseheading, goodpass, foulline)
  
  -- Heading: either manually entered or automatically taken from unit heading.
  local heading=heading or unit:GetHeading()
  
  -- Invert the heading since some units point in the "wrong" direction. In particular the strafe pit from 476th range objects.
  if inverseheading ~= nil then
    if inverseheading then
      heading=heading-180
    end
  end
  
  -- Number of hits called a "good" pass.
  local goodpass=goodpass or 20
  
  -- Foule line distance.
  local foulline=foulline or 0
  
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
  table.insert(self.strafeTargets, {name=zonename, polygon=zonepolygon, goodPass=goodpass, targets={unit}, foulline=foulline})
  
end

--- Add a unit as bombing target.
-- @param #RANGE self
-- @param Wrapper.Unit#UNIT unit Unit of the strafe target.
-- @param #number goodhitrange Max distance from unit which is considered as a good hit.
function RANGE:AddBombingTargetUnit(unit, goodhitrange)
  
  local coord=unit:GetCoordinate()
  local name=unit:GetName()
  
  -- Create a zone around the unit.
  local Vec2=coord:GetVec2()
  local Rzone=ZONE_RADIUS:New(name,Vec2,goodhitrange)
  
  -- Insert target to table.
  table.insert(self.bombingTargets, {name=name, point=coord, zone=Rzone, target=unit})
end

--- Start RANGE training.
-- @param #RANGE self
function RANGE:Start()

  -- event handler
  ---world.addEventHandler(self)
  --
  
  self:HandleEvent(EVENTS.Birth, self._OnBirth)
  self:HandleEvent(EVENTS.Hit,   self._OnHit)
  self:HandleEvent(EVENTS.Shot,  self._OnShot)
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Range event handler for envent birth.
-- @param #RANGE self
-- @param Core.Event#EVENTDATA EventData
function RANGE:_OnBirth(EventData)

  local unit  = EventData.IniUnit
  local group = EventData.IniGroup
  
  env.info(RANGE.id.."BIRTH unit  name = "..unit:GetName())
  env.info(RANGE.id.."BITH: group name = "..group:GetName())
  
  self:_PlayerEntered(unit)
  
end

--- Range event handler for envent birth.
-- @param #RANGE self
-- @param Core.Event#EVENTDATA EventData
function RANGE:_OnHit(EventData)
  self:E({eventhit = EventData})

  local unit   = EventData.IniUnit
  local unitID = unit:GetID()
  local group  = EventData.IniGroup
  local target = EventData.TgtUnit
  
  env.info("HIT: Ini unit   name = "..unit:GetName())
  env.info("HIT: Ini group  name = "..group:GetName())
  env.info("HIT: Tgt target name = "..group:GetName())
  
  local playerPos=unit:GetCoordinate()
  local targetPos=target:GetCoordinate()
  --env
  
  local _currentTarget = self.strafeStatus[unitID]

  if _currentTarget then

    -- Loop over targets (actually we allow only one at the moment.
    for _,_target in pairs(_currentTarget.zone.targets) do
    
      -- Check the the target is the same that was actually hit.
      if _target:GetName() == target:GetName() then
      
        -- Get distance between player and target.
        local dist=self:getDistance(playerPos, targetPos)
        
        if dist > _currentTarget.zone.foulline then 
          _currentTarget.hits =  _currentTarget.hits + 1
        else
          local text="RANGE: Invalid hit. Already passed foul line distance."
          MESSAGE:New(text, 30):ToAll()
          env.info(text)
        end
        
      end
    end
  end
  
  -- Bombing Targets
  for _,_target in pairs(self.bombingTargets) do
    -- Check if one of the bomb targets was hit.
    if _target.name == _event.target:getName() then
      local unit=target.unit --Wrapper.Unit#UNIT
      -- Smoke the unit.
      unit:SmokeRed()
    end
  end
  
end

--- Range event handler for event shot, i.e. when a unit releases a rocket or bomb (but not a fast firing gun). 
-- @param #RANGE self
-- @param Core.Event#EVENTDATA EventData
function RANGE:_OnShot(EventData)
  self:E({eventshot = EventData})

  local unit   = EventData.IniUnit
  local unitID = unit:GetID()
  local group  = EventData.IniGroup
  
  --local _weapon = _event.weapon:getTypeName()
  local _weapon = EventData.Weapon:getTypeName()
  
  env.info("EVENT SHOT: Ini unit    name = "..unit:GetName())
  env.info("EVENT SHOT: Ini group   name = "..group:GetName())
  env.info("EVENT SHOT: Weapon type name = ".._weapon)
  
  local _weaponStrArray = self:split(_weapon,"%.")
  local _weaponName = _weaponStrArray[#_weaponStrArray]
  

  
  
  if (string.match(_weapon, "weapons.bombs") or string.match(_weapon, "weapons.nurs")) then

    -- Weapon
    local _ordnance =  EventData.weapon

    -- Tracking info and init of last bomb position.
    env.info("Tracking ".._weapon.." - ".._ordnance:getName())
    local _lastBombPos = {x=0,y=0,z=0}

    -- Get unit name.
    --local _unitName = _event.initiator:getName()
    local _unitName = EventData.IniUnitName
    
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
        
          -- Still in the air. Remember this position.
          _lastBombPos = {x = _bombPos.x, y = _bombPos.y, z= _bombPos.z }
  
          -- Check again in 0.005 seconds.
          return timer.getTime() + 0.005
          
        else
        
          -- Bomb did hit the ground.
          -- Get closet target to last position.
          local _closetTarget = nil
          local _distance = nil
          
          -- Smoke impact point of bomb.
          local impactcoord=COORDINATE:NewFromVec3(_lastBombPos)
          impactcoord:SmokeBlue()
  
          -- Loop over defined bombing targets.
          for _,_targetZone in pairs(self.bombingTargets) do
  
            -- Distance between bomb and target.
            --TODO: define point of target. Currently, this is a coordinate. Should work.
            local _temp = self:getDistance(_targetZone.point, _lastBombPos)
  
            -- Find closest target to last known position of the bomb.
            if _distance == nil or _temp < _distance then
                _distance = _temp
                _closetTarget = _targetZone
            end
          end

          --   env.info(_distance.." from ".._closetTarget.name)
  
          -- Count if bomb fell less than 1 km away from the target.
          if _distance < 1000 then
  
            -- Init bomb player results.
            if not self.bombPlayerResults[_unit:getPlayerName()] then
              self.bombPlayerResults[_unit:getPlayerName()]  = {}
            end
  
            -- Local results.
            local _results =  self.bombPlayerResults[_unit:getPlayerName()]
            
            -- Add to table.
            table.insert(_results, {name=_closetTarget.name, distance =_distance, weapon = _weaponName })

            -- Send message to player.
            local _message = string.format("%s - %i m from bullseye of %s", _unit:getPlayerName(), _distance, _closetTarget.name)

            --TODO: MOOSE message. Why not send to group?
            trigger.action.outText(_message, 10, false)
          end
  
        end -- _status
          
      end -- end unit ~= nil
      
      return  --Terminate the timer (maybe better return nil?)
    end -- end function bombtrack

    timer.scheduleFunction(trackBomb, nil, timer.getTime() + 1)
    
  end --if string.match
end


--- Range event handler.
-- @param #RANGE self
-- @param #table _event DCS event.
-- @return #boolean
function RANGE:onEvent(_event)

  env.info("RANGE event")
  self:E({rangeevent=_event})

  if _event == nil or _event.initiator == nil then
    return true
  end
  
  if _event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
    env.info("Range event: Player entered unit! Player name = "..tostring(_event.initiator:getPlayerName()))
  elseif _event.id == world.event.S_EVENT_BIRTH then
    env.info("Range event: Birtlh! Player name = "..tostring(_event.initiator:getPlayerName()))
  end

  local playerPos=_event.initiator:getPosition().p
  local playerName=_event.initiator:getPlayerName()
  local unitName=_event.initiator:getName()
  local playerID=_event.initiator:getID()
  local groupID=self:getGroupId(_event.initiator)
  
  env.info(string.format("Player name = %s", tostring(playerName)))
  env.info(string.format("Unit   name = %s", tostring(unitName)))
  env.info(string.format("Unit     ID = %s", tostring(playerID)))
  env.info(string.format("Group    ID = %s", tostring(groupID)))

  if _event.id == 15 then --player entered unit, FF: id=15 is actually birth.
  
    env.info("RANGE: event birth")

    -- env.info("Player entered unit")
    if _event.initiator:getPlayerName() then
    
      local id=_event.initiator:getID()
      local name=_event.initiator:getName()
      
      -- Call function to init stuff.
      --TODO: unit!
      --self:_PlayerEntered(unit)
      
    end
  end
  
  if  _event.id == world.event.S_EVENT_HIT and _event.target  then

    --env.info("HIT! ".._event.target:getName().." with ".._event.weapon:getTypeName())
    --_event.weapon is currently broken for clients
    --env.info(_event.initiator:getPlayerName().."HIT! ".._event.target:getName().." with ".._event.weapon:getTypeName())
    --trigger.action.outText("HIT! ".._event.target:getName().." with ".._event.weapon:getTypeName(),10,false)
    
    -- strafeStatus holds the current strafe target the player is flying towards.
    -- In particular, _currentTarget.zone contains the current self.strafeTargets 
    local _currentTarget = self.strafeStatus[playerID]
  
    if _currentTarget then

      -- Loop over targets (actually we allow only one at the moment.
      for _,_target in pairs(_currentTarget.zone.targets) do
      
        -- Check the the target is the same that was actually hit.
        if _target:GetName() == _event.target:getName() then
        
          -- Get distance between player and target.
          local dist=self:getDistance(playerPos, _event.target:getPosition().p)
          
          if dist>_currentTarget.zone.foulline then 
            _currentTarget.hits =  _currentTarget.hits + 1
          else
            env.info("RANGE: Invalid hit. Already passed foul line distance.")
          end
          
          --TODO: this is for the pcall...
          --return true           
        end
      end
      
    end
    
    -- Bombing Targets
    for _,_target in pairs(self.bombingTargets) do
      -- Check if one of the bomb targets was hit.
      if _target.name == _event.target:getName() then
        local unit=target.unit --Wrapper.Unit#UNIT
        -- Smoke the unit.
        unit:SmokeRed()
      end
    end
    
  end

  -- Event that player fired a big weapon.
  if _event.id == world.event.S_EVENT_SHOT then

    local _weapon = _event.weapon:getTypeName()
    local _weaponStrArray = self:split(_weapon,"%.")
  
    local _weaponName = _weaponStrArray[#_weaponStrArray]
    
    -- Altitude of player. Should be greater than min alt.
    local alt=_event.initiator:getPosition().p.y
    
    if (string.match(_weapon, "weapons.bombs") or string.match(_weapon, "weapons.nurs")) then

      -- Weapon
      local _ordnance =  _event.weapon
  
      -- Tracking info and init of last bomb position.
      env.info("Tracking ".._weapon.." - ".._ordnance:getName())
      local _lastBombPos = {x=0,y=0,z=0}

      -- Get unit name.
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
          
            -- Still in the air. Remember this position.
            _lastBombPos = {x = _bombPos.x, y = _bombPos.y, z= _bombPos.z }
    
            -- Check again in 0.005 seconds.
            return timer.getTime() + 0.005
            
          else
          
            -- Bomb did hit the ground.
            -- Get closet target to last position.
            local _closetTarget = nil
            local _distance = nil
            
            -- Smoke impact point of bomb.
            local impactcoord=COORDINATE:NewFromVec3(_lastBombPos)
            impactcoord:SmokeBlue()
    
            -- Loop over defined bombing targets.
            for _,_targetZone in pairs(self.bombingTargets) do
    
              -- Distance between bomb and target.
              --TODO: define point of target. Currently, this is a coordinate. Should work.
              local _temp = self:getDistance(_targetZone.point, _lastBombPos)
    
              -- Find closest target to last known position of the bomb.
              if _distance == nil or _temp < _distance then
                  _distance = _temp
                  _closetTarget = _targetZone
              end
            end
  
            --   env.info(_distance.." from ".._closetTarget.name)
    
            -- Count if bomb fell less than 1 km away from the target.
            if _distance < 1000 then
    
              -- Init bomb player results.
              if not self.bombPlayerResults[_unit:getPlayerName()] then
                self.bombPlayerResults[_unit:getPlayerName()]  = {}
              end
    
              -- Local results.
              local _results =  self.bombPlayerResults[_unit:getPlayerName()]
              
              -- Add to table.
              table.insert(_results, {name=_closetTarget.name, distance =_distance, weapon = _weaponName })
  
              -- Send message to player.
              local _message = string.format("%s - %i m from bullseye of %s", _unit:getPlayerName(), _distance, _closetTarget.name)
  
              --TODO: MOOSE message. Why not send to group?
              trigger.action.outText(_message, 10, false)
            end
    
          end -- _status
            
        end -- end unit ~= nil
        
        return  --Terminate the timer (maybe better return nil?)
      end -- end function bombtrack

      timer.scheduleFunction(trackBomb, nil, timer.getTime() + 1)
      
    end --if string.match

  end

end

--- Function called when a player enters a unit.
-- @param #RANGE self
-- @param Wrapper.Unit#UNIT unit Unit the player has entered.
function RANGE:_PlayerEntered(unit)

  if unit then
  
    local id=unit:GetID()
    local name=unit:GetName()
    
    env.info(RANGE.id.."Unit ID   = "..tostring(id))
    env.info(RANGE.id.."Unit name = "..tostring(name))
  
    -- reset current status
    self.strafeStatus[id] = nil
  
    self:addF10Commands(name)
  
    if self.planes[id] ~= true then
  
        self.planes[id] = true
  
        self:checkInZone(name)
    end
  
  end

end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--

--- Display best 10 stafing results of a specific player.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:displayMyStrafePitResults(_unitName)

  -- Player unit.
  local _unit = Unit.getByName(_unitName)
  
  if _unit and _unit:getPlayerName() then
    local _message = "My Top 10 Strafe Pit Results:\n"
  
    local _results = self.strafePlayerResults[_unit:getPlayerName()]
  
    if _results == nil then
        -- No score so far.
        _message = _unit:getPlayerName()..": No Score yet."
    else
  
      -- Sort results table wrt number of hits.
      local _sort = function( a,b ) return a.hits > b.hits end
      table.sort(_results,_sort)
  
      -- Prepare message of best results.
      local _bestMsg = ""
      local _count = 1
      for _,_result in pairs(_results) do
  
        -- Message text.
        _message = _message.."\n"..string.format("%s - Hits %i - %s",_result.zone.name,_result.hits,_result.text)
      
        -- Best result.
        if _bestMsg == "" then 
            _bestMsg = string.format("%s - Hits %i - %s",_result.zone.name,_result.hits,_result.text)
        end
  
        -- 10 runs
        if _count == 10 then
            break
        end
    
        -- Increase counter
        _count = _count+1
      end
  
      -- Message text.
      _message = _message .."\n\nBEST: ".._bestMsg
    end

    -- Send message to group.  
    self:displayMessageToGroup(_unit, _message, 10, false)
  end
end

--- Display top 10 strafing results of all players.
-- @param #RANGE self
-- @param #string _unitName Name fo the player unit.
function RANGE:displayStrafePitResults(_unitName)

  -- Get unit from name
  local _unit = Unit.getByName(_unitName)
  
  -- Results table.
  local _playerResults = {}
  
  -- Check if we have a unit which is a player.
  if _unit and _unit:getPlayerName() then
  
    -- Message text.
    local _message = "Strafe Pit Results - Top 10:\n"
  
    -- Loop over player results.
    for _playerName,_results in pairs(self.strafePlayerResults) do
  
      -- Get the best result of the player.
      local _best = nil
      for _,_result in pairs(_results) do  
        if _best == nil or _result.hits > _best.hits then
            _best = _result
        end
      end
  
      -- Add best result to table. 
      if _best ~= nil then
        table.insert(_playerResults,{msg = string.format("%s: %s - Hits %i - %s",_playerName,_best.zone.name,_best.hits,_best.text),hits = _best.hits})
      end
  
    end
  
    --Sort list!
    local _sort = function( a,b ) return a.hits > b.hits end
    table.sort(_playerResults,_sort)
  
    -- Add top 10 results.
    for _i = 1, #_playerResults do
      _message = _message.."\n[".._i.."]".._playerResults[_i].msg
      -- Just the top 10.
      if _i > 10 then
        break
      end
    end
  
    -- Send message.
    self:displayMessageToGroup(_unit, _message, 10, false)
  end
end

--- Reset statistics.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:resetRangeStats(_unitName)

  -- Get unit.
  local _unit = Unit.getByName(_unitName)
  
  if _unit and _unit:getPlayerName() then  
    self.strafePlayerResults[_unit:getPlayerName()] = nil
    --self.bombingTargets[_unit:getPlayerName()] = nil  --This was in the original script. But I guess he means the results.
    self.bombPlayerResults[_unit:getPlayerName()] = nil
    self:displayMessageToGroup(_unit, "Range Stats Cleared.", 10, false)
  end
end

--- Display last 20 bombing run results of specific player.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:displayMyBombingResults(_unitName)

  -- Get unit.
  local _unit = Unit.getByName(_unitName)
  
  if _unit and _unit:getPlayerName() then
  
    -- Init message.
    local _message = "My Top 20 Bombing Results:\n"
  
    -- Results from player.
    local _results = self.bombPlayerResults[_unit:getPlayerName()]
  
    -- No score so far.
    if _results == nil then
      _message = _unit:getPlayerName()..": No Score yet."
    else
  
      -- Sort results wrt to distance.
      local _sort = function( a,b ) return a.distance < b.distance end
      table.sort(_results,_sort)
  
      -- Loop over results.
      local _bestMsg = ""
      local _count = 1
      for _,_result in pairs(_results) do
  
        -- Message with name, weapon and distance.
        _message = _message.."\n"..string.format("%s - %s - %i m",_result.name,_result.weapon,_result.distance)
  
        -- Store best/first result.
        if _bestMsg == "" then
            _bestMsg = string.format("%s - %s - %i m",_result.name,_result.weapon,_result.distance)
        end
  
        -- Best 20 runs only.
        if _count == 20 then
            break
        end
  
        -- Increase counter.
        _count = _count+1
      end
  
      -- Message.
      _message = _message .."\n\nBEST: ".._bestMsg
    end
  
    -- Send message.
    self:displayMessageToGroup(_unit, _message, 10, false)
  end
end

--- Display best bombing results of top 15 players.
-- @param #RANGE self
-- @param #string _unitName Name of player unit.
function RANGE:displayBombingResults(_unitName)

  -- Get unit.
  local _unit = Unit.getByName(_unitName)
  
  -- Results table.
  local _playerResults = {}
  
  -- Usual check.
  if _unit and _unit:getPlayerName() then
  
    -- Message header.
    local _message = "Bombing Results - Top 15:\n"
  
    -- Loop over players.
    for _playerName,_results in pairs(self.bombPlayerResults) do
  
      -- Find best result of player.
      local _best = nil
      for _,_result in pairs(_results) do
        if _best == nil or _result.distance < _best.distance then
            _best = _result
        end
      end
  
      -- Put best result of player into table.
      if _best ~= nil then
        local bestres=string.format("%s: %s - %s - %i m",_playerName,_best.name,_best.weapon,_best.distance)
        table.insert(_playerResults,{msg = bestres, distance = _best.distance})
      end
  
    end
  
    -- Sort list of player results.
    local _sort = function( a,b ) return a.distance < b.distance end
    table.sort(_playerResults,_sort)
  
    -- Loop over player results.
    for _i = 1, #_playerResults do
  
      -- Message text.
      _message = _message.."\n[".._i.."] ".._playerResults[_i].msg
  
      -- Top 15 player results only.
      if _i > 15 then
        break
      end
    end
  
    -- Send message.
    self:displayMessageToGroup(_unit, _message, 10,false)
  end
end

-----------------------------------------------------------------
--

--- Check if player is inside a strafing zone.
-- @param #RANGE self
-- @param #string _unitName Name of player unit.
function RANGE:checkInZone(_unitName)

  -- Check if we're in any zone
  -- if we're in a zone, start looking for hits on target
  -- if we're no longer in a zone but were previously, list the result and store the run
  local _unit = Unit.getByName(_unitName)

  if _unit and _unit:getPlayerName() then

    --TODO: Make MOOSE scheduler.
    timer.scheduleFunction(self.checkInZone, {self, _unitName}, timer.getTime() + 1)

    -- Current position of player unit.
    local _unitPos = _unit:getPosition().p --Core.Point#VEC3

    -- currently strafing?
    local _currentStrafeRun =  self.strafeStatus[_unit:getID()]

    if _currentStrafeRun ~= nil then
    
      -- Get the current approach zone and check if player is inside.
      local zone=_currentStrafeRun.zone.polygon  --Core.Zone#ZONE
      local unitinzone=zone:IsVec3InZone(_unitPos)
    
      --if _currentStrafeRun.zone.polygon~=nil and mist.pointInPolygon(_unitPos,_currentStrafeRun.zone.polygon,_currentStrafeRun.zone.maxAlt) and _unitPos.y >= _currentStrafeRun.zone.minAlt then
      if _currentStrafeRun.zone.polygon~=nil and unitinzone then
        
        -- Still in zone, do nothing. Increase counter.
        _currentStrafeRun.time = _currentStrafeRun.time+1

      elseif _currentStrafeRun.zone.polygon~=nil then

        -- Increase counter
        _currentStrafeRun.time = _currentStrafeRun.time+1

        if _currentStrafeRun.time <= 3 then
          self.strafeStatus[_unit:getID()] = nil

          -- Message text.
          local _msg = _unit:getPlayerName()..": left ".._currentStrafeRun.zone.."  too quickly. No Score. "
          
          --TODO: Moose message.
          self:displayMessageToGroup(_unit, _msg, 10, true)
          
        else
        
          -- Result.
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
          
          -- TODO: Moose message. Why not to player group only?
          trigger.action.outText(_msg, 10, false)

          self.strafeStatus[_unit:getID()] = nil

          -- Save stats so the player can retrieve them.
          local _stats = self.strafePlayerResults[_unit:getPlayerName()] or {}
          table.insert(_stats,_result)
          self.strafePlayerResults[_unit:getPlayerName()] = _stats
        end
      end

    else
      -- 
    
      -- Check to see if we're in a zone (first time)
      for _,_targetZone in pairs(self.strafeTargets) do
      
        -- Unit inside zone?
        local unitinzone=_targetZone.polygon:IsVec3InZone(_unitPos)

        --if _targetZone.polygon~=nil and mist.pointInPolygon(_unitPos,_targetZone.polygon,_targetZone.maxAlt) then
        if unitinzone then

          --if  self.strafeStatus[_unit:getID()] == nil and _unitPos.y >= _targetZone.minAlt then
          if  self.strafeStatus[_unit:getID()] == nil then

            -- Init strafe status for this player.
            self.strafeStatus[_unit:getID()] = {hits = 0, zone = _targetZone, time = 1 }

            local _msg = _unit:getPlayerName().." rolling in on ".._targetZone.name
            
            -- TODO: MOOSE message.
            self:displayMessageToGroup(_unit, _msg, 10, true)
          end

          -- We found our player. Skip remaining checks
          break
        end -- loop over zones
        
      end
    end
  else  -- Unit or PlayerName was nil
      -- Call this check again in 5 seconds.
      -- TODO: check self syntax or convert to MOOSE scheduler.
      timer.scheduleFunction(self.checkInZone, {self, _unitName}, timer.getTime() + 5)
  end
end

--- Get group id.
-- @param #RANGE self
-- @param DCS.unit#UNIT _unit DCS unit.
-- @return #number Group id.
function RANGE:getGroupId(_unit)
  
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

    local _groupId = self:getGroupId(_unit)
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

  -- Get unit from name.
  local _unit = Unit.getByName(_unitName)
  
  --TODO: why not check if playername exists?
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
