-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- **Functional** - RANGE
--  
-- ![Banner Image](..\Presentations\RAT\RAT.png)
-- 
-- ====
-- 
-- Range practice.
-- 
-- Implementation is bases on the DCS Simple Range Script by Ciribob [see here](https://forums.eagle.ru/showthread.php?t=157991 which itself was motivated)
-- by a script by SNAFU [see here](https://forums.eagle.ru/showthread.php?t=109174).
-- 
-- ## Features
--
-- * Results of all bombing and strafing runs are stored and top 10 results can be displayed. 
-- * Rocket or bomb impact point from target is measured and reported to the player.
-- * Range targets can be marked by smoke.
-- * Rocket or bomb impact points can be marked by smoke.
-- * Direct hits on target can trigger flares.
-- * Distance from rocket/bomb impact point to closest target is calculated and reported to the player.
-- * Hits on strafing passes are counted.
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
-- @field #table addTo Table for monitoring which players already got an F10 menu.
-- @field #table strafeStatus Table containing the current strafing target a player as assigned to.
-- @field #table strafePlayerResults Table containing the strafing results of each player.
-- @field #table bombPlayerResults Table containing the bombing results of each player.
-- @field #table planes Table for administration.
-- @field Core.Point#COORDINATE location Coordinate of the range.
-- @field #string rangename Name of the range.
-- @field #number nbombtargets Number of bombing targets.
-- @field #number nstrafetargets Number of strafing targets.
-- @field #table PlayerSettings Indiviual player settings.
-- @field #number dtBombtrack Time step [sec] used for tracking released bomb/rocket positions. Default 0.005 seconds.
-- @field #number Tmsg Time [sec] messages to players are displayed. Default 30 sec.
-- @field #number strafemaxalt Maximum altitude above ground for registering for a strafe run. Default is 500 m = 1650 ft. 
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
  Debug=false,
  rangename=nil,
  location=nil,
  strafeTargets={},
  bombingTargets={},
  nbombtargets=0,
  nstrafetargets=0,
  MenuAddedTo = {},
  planes = {},
  strafeStatus = {},
  strafePlayerResults = {},
  bombPlayerResults = {},
  PlayerSettings = {},
  dtBombtrack=0.005,
  Tmsg=30,
  strafemaxalt=500,
}

--- Some ID to identify who we are in output of the DCS.log file.
-- @field #string id
RANGE.id="RANGE | "

--- Range script version.
-- @field #number id
RANGE.version="0.6.0"

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- RANGE contructor.
-- @param #RANGE self
-- @param #string name
-- @return #RANGE RANGE object.
function RANGE:New(name)

  -- Inherit BASE.
  local self=BASE:Inherit(self, BASE:New()) -- #RANGE
  
  -- Get range name.
  self.rangename=name or "Practice Range"
  
  -- Debug info.
  local text=string.format("Creating new RANGE object. RANGE script version %s. Range name: %s", RANGE.version, self.rangename)
  env.info(RANGE.id..text)
  MESSAGE:New(text, 10):ToAllIf(self.Debug)
  
  -- event handler
  self:HandleEvent(EVENTS.Birth, self._OnBirth)
  self:HandleEvent(EVENTS.Hit,   self._OnHit)
  self:HandleEvent(EVENTS.Shot,  self._OnShot)
  
  -- Return object.
  return self
end

--- Initializes number of targets and location of the range and starts the RANGE training.
-- @param #RANGE self
function RANGE:Start()

  -- Location/coordinate of range.
  local _location=nil
  
  -- Count bomb targets.
  local _count=0
  for _,_target in pairs(self.bombingTargets) do
    _count=_count+1
    --_target.name
    if _location==nil then
      _location=_target.point --Core.Point#COORDINATE
    end
  end
  self.nbombtargets=_count
  
  -- Count strafing targets.
  _count=0
  for _,_target in pairs(self.strafeTargets) do
    _count=_count+1
    for _,_unit in pairs(_target.targets) do
      if _location==nil then
        _location=_unit:GetCoordinate()
      end
    end
  end
  self.nstrafetargets=_count
  
  -- Location of the range. We simply take the first unit/target we find.
  self.location=_location
  
  if self.location==nil then
    local text=string.format("ERROR! No range location found. Number of strafe targets = %d. Number of bomb targets = %d.", self.rangename, self.nstrafetargets, self.nbombtargets)
    env.info(RAT.id..text)
    return nil
  end
  
  -- Starting range.
  local text=string.format("Starting RANGE %s. Number of strafe targets = %d. Number of bomb targets = %d.", self.rangename, self.nstrafetargets, self.nbombtargets)
  env.info(RANGE.id..text)
  MESSAGE:New(text,10):ToAllIf(self.Debug)

  -- Smoke targets if debug.
  if self.Debug then
    self:SmokeBombTargets()
    self:SmokeStrafeTargets()
    self:SmokeStrafeTargetBoxes()
  end

end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- User Functions

--- Add a unit as strafe target. For a strafe target hits from guns are counted. 
-- @param #RANGE self
-- @param #table Table of unit names defining the strafe targets. The first target in the list determines the approach zone (heading and box).
-- @param #number boxlength (Optional) Length of the approach box in meters. Default is 5000 m.
-- @param #number boxwidth (Optional) Width of the approach box in meters. Default is 1000 m.
-- @param #number heading (Optional) Approach heading in Degrees. Default is heading of the unit as defined in the mission editor.
-- @param #boolean inverseheading (Optional) Take inverse heading (heading --> heading - 180 Degrees). Default is false.
-- @param #number goodpass (Optional) Number of hits for a "good" strafing pass. Default is 20.
-- @param #number foulline (Optional) Foul line distance. Hits from closer than this distance are not counted. Default 610 m = 2000 ft. Set to 0 for no foul line.
function RANGE:AddStrafeTarget(unitnames, boxlength, boxwidth, heading, inverseheading, goodpass, foulline)

  -- Create table if necessary.  
  if type(unitnames) ~= "table" then
    unitnames={unitnames}
  end
  --self:E(unitnames)
  
  -- Make targets
  local _targets={}
  local center=nil --Wrapper.Unit#UNIT
  local ntargets=0
  
  for _i,_name in ipairs(unitnames) do
  
    env.info(RANGE.id..string.format("Adding strafe target #%d %s", _i, _name))
    local unit=UNIT:FindByName(_name)
    
    if unit then
      table.insert(_targets, unit)
      -- Define center as the first unit we find
      if center==nil then
        center=unit 
      end
      ntargets=ntargets+1
    else
      local text=string.format("ERROR! Could not find strafe target with name %s.", _name)
      env.info(RANGE.id..text)
      MESSAGE:New(text, 10):ToAllIf(self.Debug)
    end
    
  end
  env.info(RANGE.id..string.format("Center unit is %s.", center:GetName())) 

  -- Approach box dimensions.
  local l=boxlength or 5000
  local w=(boxwidth or 1000)/2
  
  -- Heading: either manually entered or automatically taken from unit heading.
  local heading=heading or center:GetHeading()
  
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
  
  -- Coordinate of the range.
  local Ccenter=center:GetCoordinate()
  
  -- Name of the target defined as its unit name.
  local _name=center:GetName()

  -- Points defining the approach area.  
  local p={}
  p[#p+1]=Ccenter:Translate(  w, heading+90)
  p[#p+1]=  p[#p]:Translate(  l, heading)
  p[#p+1]=  p[#p]:Translate(2*w, heading-90)
  p[#p+1]=  p[#p]:Translate( -l, heading)
  
  local pv2={}
  for i,p in ipairs(p) do
    pv2[i]={x=p.x, y=p.z}
  end
  
  -- Create polygon zone.
  local _polygon=ZONE_POLYGON_BASE:New(_name, pv2)
    
  -- Add zone to table.
  table.insert(self.strafeTargets, {name=_name, polygon=_polygon, goodPass=goodpass, targets=_targets, foulline=foulline, smokepoints=p})
  
  -- Debug info
  local text=string.format("Adding new strafe target %s with %d targets: heading = %03d, box_L = %.1f, box_W = %.1f, goodpass = %d, foul line = %.1f", _name, ntargets, heading, boxlength, boxwidth, goodpass, foulline)
  if self.Debug then  
    env.info(RANGE.id..text)
  end
  MESSAGE:New(text, 5):ToAllIf(self.Debug)
end

--- Add bombing target(s) to range using their unit names.
-- @param #RANGE self
-- @param #table unitnames Table containing the unit names acting as bomb targets.
-- @param #number goodhitrange Max distance from target unit (in meters) which is considered as a good hit. Default is 20 m.
-- @param #boolean static Target is static. Default false.
function RANGE:AddBombingTargetsByName(unitnames, goodhitrange, static)

  -- Create a table if necessary.
  if type(unitnames) ~= "table" then
    unitnames={unitnames}
  end
  
  if static == nil or static == false then
    static=false
  else
    static=true
  end
  
  -- Default range is 20 m.
  goodhitrange=goodhitrange or 20
  
  for _,name in pairs(unitnames) do
    local _unit
    local _static
    if static then 
      local _DCSstatic=StaticObject.getByName(name)
      if _DCSstatic then
        env.info("DCS static exists")
        _DATABASE:AddStatic(name)
      else
        env.info("DCS static DOES NOT exist")
      end
      _static=STATIC:FindByName(name)
      if _static then
        self:AddBombingTargetUnit(_static, goodhitrange)
        env.info(RANGE.id.."Adding static bombing target "..name.." with hit range "..goodhitrange)
      end
    else
      _unit=UNIT:FindByName(name)
      if _unit then
        self:AddBombingTargetUnit(_unit, goodhitrange)
        env.info(RANGE.id.."Adding bombing target "..name.." with hit range "..goodhitrange)
      end
    end
--[[    
    if _unit then
      self:AddBombingTargetUnit(_unit, goodhitrange)
      env.info(RANGE.id.."Adding bombing target "..name.." with hit range "..goodhitrange)
    else
      env.info(RANGE.id.."Could not find bombing target "..name)
    end
]]
  end
end

--- Add a unit as bombing target.
-- @param #RANGE self
-- @param Wrapper.Unit#UNIT unit Unit of the strafe target.
-- @param #number goodhitrange Max distance from unit which is considered as a good hit.
function RANGE:AddBombingTargetUnit(unit, goodhitrange)
  
  local coord=unit:GetCoordinate()
  local name=unit:GetName()
  
  -- Default range is 20 m.
  goodhitrange=goodhitrange or 20  
  
  -- Create a zone around the unit.
  local Vec2=coord:GetVec2()
  local Rzone=ZONE_RADIUS:New(name, Vec2, goodhitrange)
  
  -- Insert target to table.
  table.insert(self.bombingTargets, {name=name, point=coord, zone=Rzone, target=unit})
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event Handling

--- Range event handler for envent birth.
-- @param #RANGE self
-- @param Core.Event#EVENTDATA EventData
function RANGE:_OnBirth(EventData)
  self:E({eventbirth = EventData})
  
  local _unitName=EventData.IniUnitName  
  local _unit, _playername=self:_GetPlayerUnitAndName(_unitName)
  
  if self.Debug then
    env.info(RANGE.id.."BIRTH: unit   = "..tostring(EventData.IniUnitName))
    env.info(RANGE.id.."BIRTH: group  = "..tostring(EventData.IniGroupName))
    env.info(RANGE.id.."BIRTH: player = "..tostring(_playername)) 
  end
      
  if _unit and _playername then
  
    local _uid=_unit:GetID()
    local _group=_unit:GetGroup()
    local _gid=_group:GetID()
    local _callsign=_unit:GetCallsign()
    
    -- Debug output.
    local text=string.format("Player %s, callsign %s entered unit %s (UID %d) of group %s (GID %d)", _playername, _callsign, _unitName, _uid, _group:GetName(), _gid)
    env.info(RANGE.id..text)
    MESSAGE:New(text, 5):ToAllIf(self.Debug)
    
    -- Reset current strafe status.
    self.strafeStatus[_uid] = nil
  
    -- Add Menu commands.
    --TODO: Not quite sure why this cannot be handled by the self.planes check...
    self:AddF10Commands(_unitName)
    
    -- By default, some bomb impact points and do not flare each hit on target.
    self.PlayerSettings[_playername]={}
    self.PlayerSettings[_playername].smokebombimpact=true
    self.PlayerSettings[_playername].flaredirecthits=false
  
    -- Start check in zone timer.
    if self.planes[_uid] ~= true then
      SCHEDULER:New(nil,self.CheckInZone, {self, EventData.IniDCSUnitName}, 1, 1)
      self.planes[_uid] = true
    end
  
  end
  
end

--- Range event handler for event hit.
-- @param #RANGE self
-- @param Core.Event#EVENTDATA EventData
function RANGE:_OnHit(EventData)
  self:E({eventhit = EventData})

  -- Player info
  local _unitName = EventData.IniUnitName
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  local _unitID   = _unit:GetID()

  -- Target
  local target     = EventData.TgtUnit
  local targetname = EventData.TgtUnitName 
  
  -- Debug info.
  if self.Debug then
    env.info(RANGE.id.."HIT: Ini unit   = "..tostring(EventData.IniUnitName))
    env.info(RANGE.id.."HIT: Ini group  = "..tostring(EventData.IniGroupName))
    env.info(RANGE.id.."HIT: Tgt target = "..tostring(EventData.TgtUnitName))
    env.info(RANGE.id.."HIT: Tgt group  = "..tostring(EventData.TgtGroupName))
  end
  
  -- Current strafe target of player.
  local _currentTarget = self.strafeStatus[_unitID]

  -- Player has rolled in on a strafing target.
  if _currentTarget then
  
    local playerPos = _unit:GetCoordinate()
    local targetPos = target:GetCoordinate()

    -- Loop over valid targets for this run.
    for _,_target in pairs(_currentTarget.zone.targets) do
    
      -- Check the the target is the same that was actually hit.
      if _target:GetName() == targetname then
      
        -- Get distance between player and target.
        local dist=playerPos:Get2DDistance(targetPos)
        
        if dist > _currentTarget.zone.foulline then 
          -- Increase hit counter of this run.
          _currentTarget.hits =  _currentTarget.hits + 1
          
          -- Flare target.
          if _unit and _playername and self.PlayerSettings[_playername].flaredirecthits then
            targetPos:FlareRed()
          end
        else
          -- Too close to the target.
          if _currentTarget.pastfoulline==false and _unit and _playername then 
            local _d=_currentTarget.zone.foulline           
            local text=string.format("%s, Invalid hit!\nYou already passed foul line distance of %d m for target %s.", self:_myname(_unitName), _d, targetname)
            self:DisplayMessageToGroup(_unit, text, 10)
            env.info(RANGE.id..text)
            _currentTarget.pastfoulline=true
          end
        end
        
      end
    end
  end
  
  -- Bombing Targets
  for _,_target in pairs(self.bombingTargets) do
  
    -- Check if one of the bomb targets was hit.
    if _target.name == targetname then      
      
      if _unit and _playername then
      
        local playerPos = _unit:GetCoordinate()
        local targetPos = target:GetCoordinate()
      
        -- Message to player.
        local text=string.format("%s, good hit on target %s.", self:_myname(_unitName), targetname)
        --self:DisplayMessageToGroup(_unit, text, 10, true)
        env.info(RANGE.id..text)
      
        -- Flare target.
        if self.PlayerSettings[_playername].flaredirecthits then
          targetPos:FlareRed()
        end
        
      end
    end
  end
end

--- Range event handler for event shot, i.e. when a unit releases a rocket or bomb (but not a fast firing gun). 
-- @param #RANGE self
-- @param Core.Event#EVENTDATA EventData
function RANGE:_OnShot(EventData)
  self:E({eventshot = EventData})
  
  -- Weapon data.
  local _weapon = EventData.Weapon:getTypeName()  -- should be the same as Event.WeaponTypeName
  local _weaponStrArray = self:_split(_weapon,"%.")
  local _weaponName = _weaponStrArray[#_weaponStrArray]
  
  if self.Debug then
    env.info(RANGE.id.."EVENT SHOT: Ini unit    = "..EventData.IniUnitName)
    env.info(RANGE.id.."EVENT SHOT: Ini group   = "..EventData.IniGroupName)
    env.info(RANGE.id.."EVENT SHOT: Weapon type = ".._weapon)
    env.info(RANGE.id.."EVENT SHOT: Weapon name = ".._weaponName)
  end
  
  -- Monitor only bombs and rockets.
  if (string.match(_weapon, "weapons.bombs") or string.match(_weapon, "weapons.nurs")) then

    -- Weapon
    local _ordnance =  EventData.weapon

    -- Tracking info and init of last bomb position.
    env.info(RANGE.id.."Tracking ".._weapon.." - ".._ordnance:getName())
    
    -- Init bomb position.
    local _lastBombPos = {x=0,y=0,z=0}

    -- Get unit name.
    local _unitName = EventData.IniUnitName
        
    -- Function monitoring the position of a bomb until impact.
    local function trackBomb(_previousPos)

      --local _unit = Unit.getByName(_unitName)
      --local _playername=_unit:getPlayerName()
      
      -- Get player unit and name.
      local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
      local _callsign=self:_myname(_unitName)

      -- env.info("Checking...")
      if _unit and _playername then

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
          return timer.getTime() + self.dtBombtrack
          
        else
        
          -- Bomb did hit the ground.
          -- Get closet target to last position.
          local _closetTarget = nil
          local _distance = nil
          
          -- Coordinate of impact point.
          local impactcoord=COORDINATE:NewFromVec3(_lastBombPos)
          
          -- Smoke impact point of bomb.
          if self.PlayerSettings[_playername].smokebombimpact then  
            impactcoord:SmokeBlue()
          end
              
          -- Loop over defined bombing targets.
          for _,_bombtarget in pairs(self.bombingTargets) do
  
            -- Distance between bomb and target.
            local _temp = impactcoord:Get2DDistance(_bombtarget.point)
  
            -- Find closest target to last known position of the bomb.
            if _distance == nil or _temp < _distance then
                _distance = _temp
                _closetTarget = _bombtarget
            end
          end

          -- Count if bomb fell less than 1 km away from the target.
          if _distance <= 1000 then
  
            -- Init bomb player results.
            if not self.bombPlayerResults[_playername] then
              self.bombPlayerResults[_playername]  = {}
            end
  
            -- Local results.
            local _results =  self.bombPlayerResults[_playername]
            
            -- Add to table.
            table.insert(_results, {name=_closetTarget.name, distance =_distance, weapon = _weaponName })

            -- Send message to player.
            local _message = string.format("%s, impact %i m from bullseye of target %s.", _callsign, _distance, _closetTarget.name)

            --TODO: MOOSE message. Why not send to group?
            self:DisplayMessageToGroup(_unit, _message, nil, true)
          else
            local _message=string.format("%s, weapon fell more than 1 km away from nearest range target. No score.", _callsign)
            self:DisplayMessageToGroup(_unit, _message, nil, true)
          end
  
        end -- _status
          
      end -- end unit ~= nil
      
      return nil --Terminate the timer
    end -- end function bombtrack

    timer.scheduleFunction(trackBomb, nil, timer.getTime() + 1)
    
  end --if string.match
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Display Messages

--- Display best 10 stafing results of a specific player.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:DisplayMyStrafePitResults(_unitName)
  
  -- Get player unit and name
  local _unit,_playername = self:_GetPlayerUnitAndName(_unitName)
  
  if _unit and _playername then
  
    -- Message header.
    local _message = "My Top 10 Strafe Pit Results:\n"
  
    -- Get player results.
    local _results = self.strafePlayerResults[_playername]
  
    -- Create message.
    if _results == nil then
        -- No score yet.
        _message = string.format("%s: No Score yet.", _playername)
    else
  
      -- Sort results table wrt number of hits.
      local _sort = function( a,b ) return a.hits > b.hits end
      table.sort(_results,_sort)
  
      -- Prepare message of best results.
      local _bestMsg = ""
      local _count = 1
      
      -- Loop over results
      for _,_result in pairs(_results) do
  
        -- Message text.
        _message = _message..string.format("\n[%d] %s - Hits %i - %s", _count, _result.zone.name, _result.hits, _result.text)
      
        -- Best result.
        if _bestMsg == "" then 
          _bestMsg = string.format("%s - Hits %i - %s", _result.zone.name, _result.hits, _result.text)
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
    self:DisplayMessageToGroup(_unit, _message, nil, true)
  end
end

--- Display top 10 strafing results of all players.
-- @param #RANGE self
-- @param #string _unitName Name fo the player unit.
function RANGE:DisplayStrafePitResults(_unitName)
  
  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit which is a player.
  if _unit and _playername then
  
    -- Results table.
    local _playerResults = {}
  
    -- Message text.
    local _message = "Strafe Pit Results - Top 10 Players:\n"
  
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
        local text=string.format("%s: %s - Hits %i - %s", _playerName, _best.zone.name, _best.hits, _best.text)
        table.insert(_playerResults,{msg = text, hits = _best.hits})
      end
  
    end
  
    --Sort list!
    local _sort = function( a,b ) return a.hits > b.hits end
    table.sort(_playerResults,_sort)
  
    -- Add top 10 results.
    for _i = 1, math.min(#_playerResults, 10) do
      --_message = _message.."\n[".._i.."]"..
      _message = _message..string.format("\n[%d] %s", _i, _playerResults[_i].msg)
    end
  
    -- Send message.
    self:DisplayMessageToGroup(_unit, _message, nil, true)
  end
end

--- Display last 20 bombing run results of specific player.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:DisplayMyBombingResults(_unitName)

  -- Get player unit and name.  
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  if _unit and _playername then
  
    -- Init message.
    local _message = "My Top 10 Bombing Results:\n"
  
    -- Results from player.
    local _results = self.bombPlayerResults[_playername]
  
    -- No score so far.
    if _results == nil then
      _message = _playername..": No Score yet."
    else
  
      -- Sort results wrt to distance.
      local _sort = function( a,b ) return a.distance < b.distance end
      table.sort(_results,_sort)
  
      -- Loop over results.
      local _bestMsg = ""
      local _count = 1
      for _,_result in pairs(_results) do
  
        -- Message with name, weapon and distance.
        _message = _message.."\n"..string.format("[%d] %s - %s - %i m", _count, _result.name, _result.weapon, _result.distance)
  
        -- Store best/first result.
        if _bestMsg == "" then
            _bestMsg = string.format("%s - %s - %i m",_result.name,_result.weapon,_result.distance)
        end
  
        -- Best 10 runs only.
        if _count == 10 then
          break
        end
  
        -- Increase counter.
        _count = _count+1
      end
  
      -- Message.
      _message = _message .."\n\nBEST: ".._bestMsg
    end
  
    -- Send message.
    self:DisplayMessageToGroup(_unit, _message, nil, true)
  end
end

--- Display best bombing results of top 10 players.
-- @param #RANGE self
-- @param #string _unitName Name of player unit.
function RANGE:DisplayBombingResults(_unitName)
  
  -- Results table.
  local _playerResults = {}
  
  -- Get player unit and name.
  local _unit, _player = self:_GetPlayerUnitAndName(_unitName)
  
  -- Check if we have a unit with a player.
  if _unit and _player then
  
    -- Message header.
    local _message = "Bombing Results - Top 10 Players:\n"
  
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
        local bestres=string.format("%s: %s - %s - %i m", _playerName, _best.name, _best.weapon, _best.distance)
        table.insert(_playerResults, {msg = bestres, distance = _best.distance})
      end
  
    end
  
    -- Sort list of player results.
    local _sort = function( a,b ) return a.distance < b.distance end
    table.sort(_playerResults,_sort)
  
    -- Loop over player results.
    for _i = 1, math.min(#_playerResults, 10) do  
      -- Message text.
      --_message = _message.."\n[".._i.."] "..
      _message = _message..string.format("\n[%d] %s", _i, _playerResults[_i].msg)
    end
  
    -- Send message.
    self:DisplayMessageToGroup(_unit, _message, nil, true)
  end
end

--- Report absolute bearing and range form player unit to airport.
-- @param #RANGE self
-- @param #string _unitname Name of the player unit.
function RANGE:RangeInfo(_unitname)

  -- Get player unit and player name.
  local unit, playername = self:_GetPlayerUnitAndName(_unitname)
  
  -- Check if we have a player.
  if unit and playername then
  
    -- Message text.
    local text=""
   
    -- Current coordinates.
    local coord=unit:GetCoordinate()
    
    if self.location then
    
      -- Get atmospheric data at range location.
      local position=self.location --Core.Point#COORDINATE
      local T=position:GetTemperature()
      local P=position:GetPressure()
      local Wd,Ws=position:GetWind()
      
      -- Get Beaufort wind scale.
      local Bn,Bd=UTILS.BeaufortScale(Ws)  
      
      -- Direction vector from current position (coord) to target (position).
      local vec3=coord:GetDirectionVec3(position)
      local angle=coord:GetAngleDegrees(vec3)
      local range=coord:Get2DDistance(position)
      
      -- Bearing string.
      local Bs=string.format('%03d°', angle)
      local WD=string.format('%03d°', Wd)
      local Ts=string.format("%d°C",T)
      
      local hPa2inHg=0.0295299830714
      local hPa2mmHg=0.7500615613030
      
      local textbomb
      if self.PlayerSettings[playername].smokebombimpact then
        textbomb=string.format("Smoke bomb impact points: ON\n")
      else
        textbomb=string.format("Smoke bomb impact points: OFF\n")
      end
      local texthit
      if self.PlayerSettings[playername].flaredirecthits then
        texthit=string.format("Flare direct hits: ON\n")
      else
        texthit=string.format("Flare direct hits: OFF\n")
      end
       
      -- Message text.
      text=text..string.format("Information on %s:\n", self.rangename)
      text=text..string.format("--------------------------------------------------\n")
      text=text..string.format("Bearing %s, Range %.1f km.", Bs, range/1000)
      text=text..string.format("# of strafe targets: %d\n", self.nstrafetargets)
      text=text..string.format("# of bomb targets: %d\n", self.nbombtargets)
      text=text..textbomb
      text=text..texthit
      text=text.."\n"
      text=text.."Weather Report:\n"
      text=text..string.format("--------------------------------------------------\n")
      text=text..string.format("Temperature %s\n", Ts)
      text=text..string.format("Wind from %s at %.1f m/s (%s)\n", WD, Ws, Bd)
      text=text..string.format("QFE %.1f hPa = %.1f mmHg = %.0f inHg\n", P, P*hPa2mmHg, P*hPa2inHg)
    else
      text=string.format("No targets have been defined for range %s.", self.rangename)
    end
    
    -- Send message to player group.
    self:DisplayMessageToGroup(unit, text, nil, true)
    
    if self.Debug then
      env.info(RANGE.id..text)
    end
  else
    env.info(RANGE.id.."ERROR! Could not find player unit in RangeInfo! Name = ".._unitname)
  end      
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Timer Functions

--- Check if player is inside a strafing zone. If he is, we start looking for hits. If he was and left the zone again, the result is stored.
-- @param #RANGE self
-- @param #string _unitName Name of player unit.
function RANGE:CheckInZone(_unitName)

  -- Get player unit and name.
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)

  if _unit and _playername then

    -- Current position of player unit.
    local _unitID  = _unit:GetID()

    -- Currently strafing? (strafeStatus is nil if not)
    local _currentStrafeRun = self.strafeStatus[_unitID]

    if _currentStrafeRun then  -- player has already registered for a strafing run.
    
      -- Get the current approach zone and check if player is inside.
      local zone=_currentStrafeRun.zone.polygon  --Core.Zone#ZONE_POLYGON_BASE
      
      -- Check if unit is inside zone and below max height AGL.
      local unitinzone=_unit:IsInZone(zone) and _unit:GetHeight()-_unit:GetCoordinate():GetLandHeight() <= self.strafemaxalt
      
      if self.Debug then
        local text=string.format("Checking zone. Unit = %s, player = %s in zone = %s", _unitName, _playername, tostring(unitinzone))
        env.info(RANGE.id..text)
      end
    
      -- Check if player is in strafe zone and below max alt.
      if unitinzone then 
        
        -- Still in zone, keep counting hits. Increase counter.
        _currentStrafeRun.time = _currentStrafeRun.time+1
    
      else
    
        -- Increase counter
        _currentStrafeRun.time = _currentStrafeRun.time+1
    
        if _currentStrafeRun.time <= 3 then
        
          -- Reset current run.
          self.strafeStatus[_unitID] = nil
    
          -- Message text.
          local _msg = string.format("%s left strafing zone %s too quickly. No Score.", _playername, _currentStrafeRun.zone.name)
          
          -- Send message.
          self:DisplayMessageToGroup(_unit, _msg, nil, true)
          
        else
        
          -- Result.
          local _result = self.strafeStatus[_unitID]

          -- Judge this pass. Text is displayed on summary.
          if _result.hits >= _result.zone.goodPass*2 then
            _result.text = "EXCELLENT PASS"    
          elseif _result.hits >= _result.zone.goodPass then
            _result.text = "GOOD PASS"
          elseif _result.hits >= _result.zone.goodPass/2 then
            _result.text = "INEFFECTIVE PASS"
          else
            _result.text = "POOR PASS"
          end
    
          -- Message text.      
          local _text=string.format("%s, %s with %d hits on target %s.", self:_myname(_unitName), _result.text, _result.hits, _result.zone.name)
          
          -- Send message.
          self:DisplayMessageToGroup(_unit, _text)
    
          -- Set strafe status to nil.
          self.strafeStatus[_unitID] = nil
    
          -- Save stats so the player can retrieve them.
          local _stats = self.strafePlayerResults[_playername] or {}
          table.insert(_stats, _result)
          self.strafePlayerResults[_playername] = _stats
        end
        
      end

    else
    
      -- Check to see if we're in any of the strafing zones (first time).
      for _,_targetZone in pairs(self.strafeTargets) do
        
        -- Get the current approach zone and check if player is inside.
        local zonenname=_targetZone.name
        local zone=_targetZone.polygon  --Core.Zone#ZONE_POLYGON_BASE
      
        -- Check if player is in zone and below
        local unitinzone=_unit:IsInZone(zone) and _unit:GetHeight()-_unit:GetCoordinate():GetLandHeight() <= self.strafemaxalt
           
        if self.Debug then
          local text=string.format("Checking zone %s. Unit = %s, player = %s in zone = %s", _targetZone.name, _unitName, _playername, tostring(unitinzone))
          --MESSAGE:New(text, 10):ToAllIf(self.Debug)
          env.info(RANGE.id..text)
        end
        
        -- Player is inside zone.
        if unitinzone then

          -- Init strafe status for this player.
          self.strafeStatus[_unitID] = {hits = 0, zone = _targetZone, time = 1, pastfoulline=false }
  
          -- Rolling in!
          local _msg=string.format("%s, rolling in on strafe pit %s.", self:_myname(_unitName), _targetZone.name)
          
          -- TODO: MOOSE message.
          self:DisplayMessageToGroup(_unit, _msg, 10, true)

          -- We found our player. Skip remaining checks.
          break
          
        end -- unit in zone check 
        
      end -- loop over zones
    end
  end
  
end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Menu Functions

--- Add menu commands for player.
-- @param #RANGE self
-- @param #string _unitName Name of player unit.
function RANGE:AddF10Commands(_unitName)
  
  local _unit, playername = self:_GetPlayerUnitAndName(_unitName)
  
  --TODO: why not check if playername exists?
  if _unit and playername then

    --local _gid=self:getGroupId(_unit)  
    --local unit=UNIT:Find(_unit)
    local group=_unit:GetGroup()
    local _gid=group:GetID()
    --local playername=unit:GetPlayerName()
  
    --if _group then
    if group and _gid then
  
      --local _gid =  _group.groupId
      if not self.MenuAddedTo[_gid] then
      
        -- Enable switch so we don't do this twice.
        self.MenuAddedTo[_gid] = true
  
        -- Main F10 menu: F10/On the Range
        local _rootPath = missionCommands.addSubMenuForGroup(_gid, "On the Range")
        -- Submenu for this range: F10/On the Range/<Range Name>
        local _rangePath = missionCommands.addSubMenuForGroup(_gid, self.rangename, _rootPath)
        local _smokePath = missionCommands.addSubMenuForGroup(_gid, "Smoke Targets", _rangePath)

        --TODO: Convert to MOOSE menu.
        -- Commands
        missionCommands.addCommandForGroup(_gid, "Mark Targets On Map",      _smokePath, self.MarkTargetsOnMap, self, _unitName)
        missionCommands.addCommandForGroup(_gid, "Illuminate Targets",       _smokePath, self.IlluminateBombTargets, self)        
        missionCommands.addCommandForGroup(_gid, "Smoke Strafe Approaches",  _smokePath, self.SmokeStrafeTargetBoxes, self)        
        missionCommands.addCommandForGroup(_gid, "Smoke Strafe Targets",     _smokePath, self.SmokeStrafeTargets, self)
        missionCommands.addCommandForGroup(_gid, "Smoke Bombing Targets",    _smokePath, self.SmokeBombTargets, self)
        missionCommands.addCommandForGroup(_gid, "Smoke Bomb Impact On/Off", _smokePath, self.SmokeBombImpactOnOff, self, _unitName)
        missionCommands.addCommandForGroup(_gid, "Flare Direct Hits On/Off", _smokePath, self.FlareDirectHitsOnOff, self, _unitName)
        missionCommands.addCommandForGroup(_gid, "Range Information",        _rangePath, self.RangeInfo, self, _unitName)
        missionCommands.addCommandForGroup(_gid, "All Strafe results",       _rangePath, self.DisplayStrafePitResults, self, _unitName)
        missionCommands.addCommandForGroup(_gid, "All Bombing results",      _rangePath, self.DisplayBombingResults, self, _unitName)
        missionCommands.addCommandForGroup(_gid, "My Strafe results",        _rangePath, self.DisplayMyStrafePitResults, self, _unitName)
        missionCommands.addCommandForGroup(_gid, "My Bombing results",       _rangePath, self.DisplayMyBombingResults, self, _unitName)
        missionCommands.addCommandForGroup(_gid, "Reset Stats",              _rangePath, self.ResetRangeStats, self, _unitName)
        
      end
    else
      env.info(RANGE.id.."ERROR! Could not find group or group ID in AddF10Menu() function. Unit name: ".._unitName)
    end
  else
    env.info(RANGE.id.."ERROR! Player unit does not exist in AddF10Menu() function. Unit name: ".._unitName)
  end

end

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Helper Functions

--- Mark targets on F10 map.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:MarkTargetsOnMap(_unitName)
  -- Get group.
  local group=UNIT:FindByName(_unitName):GetGroup()

  if group then
  
    -- Mark bomb targets.
    for _,_target in pairs(self.bombingTargets) do
      local coord=_target.point --Core.Point#COORDINATE
      coord:MarkToGroup("Strafe target ".._target.name, group)
    end
    
    -- Mark strafe targets.
    for _,_strafepit in pairs(self.strafeTargets) do
      for _,_target in pairs(_strafepit.targets) do
        local coord=_target:GetCoordinate() --Core.Point#COORDINATE
        coord:MarkToGroup("Strafe target ".._target:GetName(), group)
      end
    end
    
  end
end

--- Illuminate targets.
-- @param #RANGE self
function RANGE:IlluminateBombTargets()

  local bomb={}

  for _,_target in pairs(self.bombingTargets) do
    local coord=_target.point --Core.Point#COORDINATE
    table.insert(bomb, coord)
  end
  
  if #bomb>0 then
    local coord=bomb[math.random(#bomb)] --Core.Point#COORDINATE
    local c=COORDINATE:New(coord.x,coord.y+math.random(400,800),coord.z)
    c:IlluminationBomb()
  end
  
  -- All strafe target coordinates.
  local strafe={}
  
  for _,_strafepit in pairs(self.strafeTargets) do
    for _,_target in pairs(_strafepit.targets) do
      local coord=_target:GetCoordinate() --Core.Point#COORDINATE
      table.insert(strafe, coord)
    end
  end
  
  -- Pick a random strafe target.
  if #strafe>0 then
    local coord=strafe[math.random(#strafe)] --Core.Point#COORDINATE
    local c=COORDINATE:New(coord.x,coord.y+math.random(400,800),coord.z)
    c:IlluminationBomb()
  end  
end

--- Reset statistics.
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
function RANGE:ResetRangeStats(_unitName)

  -- Get player unit and name.  
  local _unit, _playername = self:_GetPlayerUnitAndName(_unitName)
  
  if _unit and _playername then  
    self.strafePlayerResults[_playername] = nil
    self.bombPlayerResults[_playername] = nil
    self:DisplayMessageToGroup(_unit, "Range Stats Cleared.", 5)
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
-- @param Wrapper.Unit#UNIT _unit Player unit.
-- @param #string _text Message text.
-- @param #number _time Duration how long the message is displayed.
-- @param #boolean _clear Clear up old messages.
function RANGE:DisplayMessageToGroup(_unit, _text, _time, _clear)
  
  _time=_time or self.Tmsg
  if _clear==nil then
    _clear=false
  end
  
    -- Group ID.
  local _gid=_unit:GetGroup():GetID()
  
  if _gid then
    if _clear == true then
      trigger.action.outTextForGroup(_gid, _text, _time, _clear)
    else
      trigger.action.outTextForGroup(_gid, _text, _time)
    end
  end
end

--- Toggle status of smoking bomb impact points.
-- @param #RANGE self
-- @param #string unitname Name of the player unit.
function RANGE:SmokeBombImpactOnOff(unitname)
  local unit, playername = self:_GetPlayerUnitAndName(unitname)
  if unit and playername then
    local text
    if self.PlayerSettings[playername].smokebombimpact==true then
      self.PlayerSettings[playername].smokebombimpact=false
      text=string.format("Smoking impact points of bombs is now OFF.\n")
    else
      self.PlayerSettigs[playername].smokebombimpact=true
      text=string.format("Smoking impact points of bombs is now ON.\n")
    end
    self:DisplayMessageToGroup(unit, text, 5)
  end
end

--- Toggle status of flaring direct hits of range targets.
-- @param #RANGE self
-- @param #string unitname Name of the player unit.
function RANGE:FlareDirectHitsOnOff(unitname)
  local unit, playername = self:_GetPlayerUnitAndName(unitname)
  if unit and playername then
    local text
    if self.PlayerSettings[playername].flaredirecthits==true then
      self.PlayerSettings[playername].flaredirecthits=false
      text=string.format("Flare direct hits is now OFF.\n")
    else
      self.PlayerSettings[playername].flaredirecthits=true
      text=string.format("Flare direct hits is now ON.\n")
    end
    self:DisplayMessageToGroup(unit, text, 5)
  end
end

--- Get distance in meters assuming a Flat world.
-- @param #RANGE self
function RANGE:SmokeBombTargets()
  for _,_target in pairs(self.bombingTargets) do
    local coord = _target.point --Core.Point#COORDINATE
    coord:SmokeRed()
  end
end

--- Get distance in meters assuming a Flat world.
-- @param #RANGE self
function RANGE:SmokeStrafeTargets()
  for _,_target in pairs(self.strafeTargets) do
    for _,_unit in pairs(_target.targets) do
      local coord = _unit:GetCoordinate() --Core.Point#COORDINATE
      coord:SmokeGreen()
    end
  end
end

--- Smoke approach boxes of strafe targets.
-- @param #RANGE self
function RANGE:SmokeStrafeTargetBoxes()
  for _,_target in pairs(self.strafeTargets) do
    local zone=_target.polygon --Core.Zone#ZONE
    zone:SmokeZone(SMOKECOLOR.White)
    for _,_point in pairs(_target.smokepoints) do
      _point:SmokeOrange()
    end
  end
end

--- Returns the unit of a player and the player name. If the unit does not belong to a player, nil is returned. 
-- @param #RANGE self
-- @param #string _unitName Name of the player unit.
-- @return Wrapper.Unit#UNIT Unit of player.
-- @return #string Name of the player.
-- @return nil If player does not exist.
function RANGE:_GetPlayerUnitAndName(_unitName)

  local DCSunit=Unit.getByName(_unitName)
  local playername=DCSunit:getPlayerName()
  local unit=UNIT:Find(DCSunit)
  
  if DCSunit and unit and playername then
    return unit, playername
  end
  
  return nil,nil
end

--- Returns a string which consits of this callsign and the player name.  
-- @param #RANGE self
-- @param #string unitname Name of the player unit.
function RANGE:_myname(unitname)
  local unit=UNIT:FindByName(unitname)
  local pname=unit:GetPlayerName()
  local csign=unit:GetCallsign()
  return string.format("%s (%s)", csign, pname)
end


--- http://stackoverflow.com/questions/1426954/split-string-in-lua
-- @param #RANGE self
-- @param #string str Sting to split.
-- @param #string sep Speparator for split.
-- @return #table Split text.
function RANGE:_split(str, sep)
  local result = {}
  local regex = ("([^%s]+)"):format(sep)
  for each in str:gmatch(regex) do
      table.insert(result, each)
  end
  return result
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
