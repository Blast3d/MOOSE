-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- **Functional** - Pseudo ATC.
--  
-- ![Banner Image](..\Presentations\RAT\RAT.png)
-- 
-- ====
-- 
-- The pseudo ATC enhances the standard DCS ATC functions.
-- 
-- In particular, ...
-- 
-- ## Features
-- 
-- * Report QFE, QNH at nearby airbases. Pressure units: hPa (european aircraft), mmHg (russian aircraft), inHg (american aircraft).
-- * Report wind direction and strength at airbases.
-- * Report temperature at airbases.
-- * Report absolute bearing and range to nearest airports.
-- * Report current AGL height of own aircraft.
-- * Upon request, ATC reports height until touchdown. Reporting frequency increases with decreasing height.
-- * Pressure temperature, wind data and BR for mission waypoints.
-- * Works with static and dynamic weather.
-- * All maps supported (Caucasus, NTTR, Normandy, and all future maps).
-- * Multiplayer ready (?) (I suppose yes, but I don't have a server to test or debug. Jumping from client to client works.)
--  
--  The PSEUDOATC class creates an entry in the F10 menu which allows to
--  
--  * Create new groups on-the-fly, i.e. at run time within the mission,
--  * Destroy specific groups (e.g. if they get stuck or damaged and block a runway),
--  * Request the status of all RAT aircraft or individual groups,
--  * Place markers at waypoints on the F10 map for each group.
-- 
-- ====
-- 
-- # Demo Missions
--
-- ### [RAT Demo Missions](https://github.com/FlightControl-Master/MOOSE_MISSIONS/tree/Release/RAT%20-%20Random%20Air%20Traffic)
-- ### [ALL Demo Missions pack of the last release](https://github.com/FlightControl-Master/MOOSE_MISSIONS/releases)
-- 
-- ====
-- 
-- # YouTube Channel
-- 
-- ### RAT videos are work in progress.
-- ### [MOOSE YouTube Channel](https://www.youtube.com/playlist?list=PL7ZUrU4zZUl1jirWIo4t4YxqN-HxjqRkL)
-- 
-- ===
-- 
-- ### Author: **[funkyfranky](https://forums.eagle.ru/member.php?u=115026)**
-- 
-- ### Contributions: **Sven van de Velde ([FlightControl](https://forums.eagle.ru/member.php?u=89536))**
-- 
-- ====
-- @module PeusoATC

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- PSEUDOATC class
-- @type PSEUDOATC
-- @field #string ClassName Name of the Class.
-- @field #boolean Debug If true, print debug info to dcs.log file.
-- @field #table player Table comprising the player info.
-- @extends Core.Base#BASE

---# PSEUDOATC class, extends @{Base#BASE}
-- The PSEUDOATC class
-- 
--
-- ## Airport Selection
-- 
-- ![Process](..\Presentations\RAT\RAT_Airport_Selection.png)
-- 
-- ### Default settings:
-- 
-- * By default, aircraft are spawned at airports of their own coalition (blue or red) or neutral airports.
-- * Destination airports are by default also of neutral or of the same coalition as the template group of the spawned aircraft.
-- * Possible destinations are restricted by their distance to the departure airport. The maximal distance depends on the max range of spawned aircraft type and its initial fuel amount.
-- 
-- ### The default behavior can be changed:
-- 
-- * A specific departure and/or destination airport can be chosen.
-- * Valid coalitions can be set, e.g. only red, blue or neutral, all three "colours".
-- * It is possible to start in air within a zone defined in the mission editor or within a zone above an airport of the map.
-- 
-- 
-- @field #PSEUDOATC
PSEUDOATC={
  ClassName = "PSEUDOATC",
  Debug=true,
  player={},
  maxairport=9,
}

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Main F10 menu.
-- @field #string MenuF10
PSEUDOATC.MenuF10=nil

--- RAT unit conversions.
-- @list unit
PSEUDOATC.unit={
  hPa2inHg=0.0295299830714,
  hPa2mmHg=0.7500615613030,
}

--- Some ID to identify who we are in output of the DCS.log file.
-- @field #string id
PSEUDOATC.id="PseudoATC | "

--- PSEUDOATC version.
-- @field #list
PSEUDOATC.version={
  version = "0.1.2",
  print = true,
}

--[[
local peter={}

--- Event handler for suppressed groups.
--@param #PSEUOATC self
--@param #table event Event table info.
function peter:onEvent(event)

  env.info("peter: Some event occurred. event id = "..event.id)
  
  local Tnow=timer.getTime()
      
  -- Event Player Entered Unit
  if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
  
    local unit=event.initiator -- Wrapper.Unit#UNIT
   
    if unit and unit:isExist() then
      
      local name=unit:getName()  
      env.info(string.format("peter: Some player just entered unit %s.", name))
      
    end

  end
  
end

world.addEventHandler(peter)
]]

--- PSEUDOATC contructor.
-- @param #PSEUDOATC self
-- @return #PSEUDOATC Returns a PSEUDOATC object.
function PSEUDOATC:New()

  -- Inherit BASE.
  local self=BASE:Inherit(self, BASE:New()) -- #PSEUDOATC
  
  -- Debug info
  env.info(PSEUDOATC.id..string.format("Creating PseudoATC object. PseudoATC version %s",PSEUDOATC.version.version))
  
  -- Handle events.
  --self:HandleEvent(EVENTS.PlayerEnterUnit, self._PlayerEntered)
  --self:HandleEvent(EVENTS.PlayerLeaveUnit, self._PlayerLeft)
  --self:HandleEvent(EVENTS.PilotDead, self._PlayerLeft)
  --self:HandleEvent(EVENTS.Land, self._PlayerLanded)
  --self:HandleEvent(EVENTS.Takeoff, self._PlayerTakeoff)
  
  -- event handler when players enter or leave (multiplayer)
  world.addEventHandler(self)
  
  -- Return object.
  return self
end

--- Function called when a player enters a unit.
-- @param #PSEUDOATC self
-- @param Core.Event#EVENTDATA EventData
function PSEUDOATC:_PlayerEntered(EventData)
  env.info(PSEUDOATC.id.."player entered")

  local unit=EventData.IniUnit --Wrapper.Unit#UNIT
  
  if unit then
 
    self:PlayerEntered(unit)
 
  end               
 
end

--- Event handler for suppressed groups.
--@param #PSEUDOATC self
--@param #table event Event table info.
function PSEUDOATC:onEvent(event)
    
  -- Event Player Entered Unit
  if event.id == world.event.S_EVENT_PLAYER_ENTER_UNIT then
  
    local DCSunit=event.initiator

    if DCSunit and DCSunit:isExist() then
      
      local name=DCSunit:getName()  
      env.info(PSEUDOATC.id..string.format("Some player just entered unit %s", name))
      local unit=UNIT:FindByName(name)
      unit:GetGroup()
      
      self:PlayerEntered(unit)
      
    end

  end
  
end

-- get player unit (single player case)
local PlayerUnit=world.getPlayer()
if PlayerUnit then
  PSEUDOATC:PlayerEntered(PlayerUnit)
end

--- Function called when a player enters a unit.
-- @param #PSEUDOATC self
-- @param Wrapper.Unit#UNIT unit Unit the player entered.
function PSEUDOATC:PlayerEntered(unit)

  local group=unit:GetGroup() --Wrapper.Group#GROUP
  local GID=group:GetID()
  local GroupName=group:GetName()
  local PlayerName=unit:GetPlayerName()
  local UnitName=unit:GetName()
  
  self.player[GID].group=group
  self.player[GID].groupname=GroupName
  self.player[GID].unitname=UnitName
  self.player[GID].waypoints=group:GetTaskRoute()
  self.player[GID].scheduler={}
  self.player[GID].schedulerid={}
  
  -- Array holding all menues for this player.
  self.player[GID].menu={}
   
  -- Info message.
  local text=string.format("Player %s entered unit %s of group %s. ID = %d", PlayerName, UnitName, GroupName, GID)
  if self.Debug then
    MESSAGE:New(text, 30):ToGroup(group)
    env.info(PSEUDOATC.id..text)
  end
  
  -- Create main F10 menu, i.e. "F10/Pseudo ATC"
  self.player[GID].menu.main=missionCommands.addSubMenu('Pseudo ATC')
  
  -- Create menu for new player.
  self.CreateMenu(unit)
  
  -- Start scheduler to refresh the F10 menues.
  self.player[GID].scheduler.menu, self.player[GID].schedulerid.menu=SCHEDULER:New(nil,self.MenuRefresh,{self, GID}, 5, 30)
 
end

--- Function called when a player leaves a unit or dies. 
-- @param #PSEUDOATC self
-- @param Core.Event#EVENTDATA EventData
function PSEUDOATC:_PlayerLeft(EventData)
  --missionCommands.removeItem(F10menu_ATC)
  --stop timers
  --remove arrays.
end


--- Create list of nearby airports sorted by distance to player unit.
-- @param #PSEUDOATC self
-- @param #number id Group id of player unit.
function PSEUDOATC:_LocalAirports(id)

  -- Airports table.  
  self.player[id].airports=nil
  self.player[id].airports={}
  
  -- Current player position.
  local pos=self.player[id].unit:GetCoordinate()
  
  -- Loop over coalitions.
  for i=0,2 do
    
    -- Get all airbases of coalition.
    local airports=coalition.getAirbases(i)
    
    -- Loop over airbases
    for _,airbase in pairs(airports) do
    
      local name=airbase:getName()
      local q=AIRBASE:FindByName(name):GetCoordinate()
      local d=q:Get2DDistance(pos)
      
      -- Add to table.
      table.insert(self.player[id].airports, {distance=d, name=name})
      
    end
  end
  
  --- compare distance (for sorting airports)
  local function compare(a,b)
    return a.distance < b.distance
  end
  
  -- Sort airports table w.r.t. distance to player.
  table.sort(self.player[id].airports, compare)
  
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- Menu Functions

--- Refreshes all player menues.
-- @param #PSEUDOATC self.
-- @param #number id Group id of player unit. 
function PSEUDOATC:MenuRefresh(id)

  -- Clear menu.
  self:MenuClear(id)
  
  -- create list of airports
  self:_LocalAirports(id)
  
  -- create submenu airports
  self:MenuAirports(id)
  
  -- create submenu My Positon
  menu_add_plane(unit)
end


--- Clear player menues.
-- @param #PSEUDOATC self.
-- @param #number id Group id of player unit. 
function PSEUDOATC:MenuClear(id)

  if self.player[id].menu.airports then
    for name,item in pairs(self.player[id].menu.airports) do
    
      if self.Debug then
        env.info(PSEUDOATC.id..string.format("Deleting menu item %s for ID %d", name, id))
      end
      
      missionCommands.removeItemForGroup(id, self.player[id].menu.airports.name)
    end
  end
end

--- Create "F10/Pseudo ATC" menu items "Airport Data".
-- @param #PSEUDOATC self
-- @param #number id Group id of player unit for which menues are created. 
function PSEUDOATC:MenuAirports(id)

  self.player[id].menu.airports=nil
  self.player[id].menu.airports={}
      
  local i=0
  for _,airport in pairs(self.player[id].airports) do
  
    i=i+1
    if i>self.maxairport then
      break -- Max X<10 airports due to 10 menu items restriction.
    end 
    
    local name=airport.name
    local d=airport.distance
    local pos=AIRBASE:FindByName(n):GetCoordinate()
    
    --F10menu_ATC_airports[ID][name] = missionCommands.addSubMenuForGroup(ID, name, F10menu_ATC)
    self.player[id].menu.airports.name = missionCommands.addSubMenuForGroup(id, name, self.player[id].menu.main)
    
    -- Create menu reporting commands
    missionCommands.addCommandForGroup(id, "Request QFE", self.player[id].menu.airports.name, self.ReportPressure, self, id, "QFE", pos, name)
    missionCommands.addCommandForGroup(id, "Request QNH", self.player[id].menu.airports.name, self.ReportPressure, self, id, "QNH", pos, name)
    missionCommands.addCommandForGroup(id, "Request Wind", self.player[id].menu.airports.name, self.ReportWind, self, id, pos, name)
    missionCommands.addCommandForGroup(id, "Request Temperature", self.player[id].menu.airports.name, self.ReportTemperature, self, id, pos, name)
    missionCommands.addCommandForGroup(id, "Request BR", self.player[id].menu.airports.name, self.ReportBR, self, id, pos, name, self.player[id].unit)
    
    if self.Debug then
      env.info(string.format(PSEUDOATC.id.."Creating airport menu item %s for ID %d", name, id))
    end
  end
end

--- Create F10/Pseudo ATC menu item "My Plane".
-- @param #PSEUDOATC self
-- @param #number id Group id of player unit for which menues are created. 
function PSEUDOATC:MenuAircraft(id)

  local name="My Aircraft ("..self.player[id].unit:getCallsign()..")"
  if self.Debug then
    env.info(PSEUDOATC.id.."Creating menu item "..name.." for ID "..id)
  end
  
  -- F10/PseudoATC/My Aircraft (callsign)
  self.player[id].menu.aircraft = missionCommands.addSubMenuForGroup(id, name, self.player[id].menu.main)
  
  -- F10/PseudoATC/My Aircraft (callsign)/Waypoints
  if #self.player[id].waypoints>0 then
  
    --F10menu_ATC_waypoints[ID]={}
    self.player[id].menu.waypoints={}
    self.player[id].menu.waypoints.main=missionCommands.addSubMenuForGroup(id, "Waypoints", self.player[id].menu.aircraft)

    local j=0    
    for i,pos in pairs(self.player[id].waypoints) do
      -- Increase counter
      j=j+1
      
      if j>10 then
        break -- max ten menu entries
      end
       
      local fname="Waypoint "..tostring(i-1).." for "..self.player[id].unit:getCallsign()
      local pname="Waypoint "..tostring(i-1)
      
      -- "F10/PseudoATC/My Aircraft (callsign)/Waypoints/Waypoint X"
      self.player[id].menu.waypoints.pname=missionCommands.addSubMenuForGroup(id, pname, self.player[id].menu.waypoints.main)
      
      -- Menu commands for each waypoint "F10/PseudoATC/My Aircraft (callsign)/Waypoints/Waypoint X/<Commands>"
      missionCommands.addCommandForGroup(id, "Request QFE", self.player[id].menu.waypoints.pname, self.ReportPressure, self, id, "QFE", pos, fname)
      missionCommands.addCommandForGroup(id, "Request QNH", self.player[id].menu.waypoints.pname, self.ReportPressure, self, id, "QNH", pos, fname)
      missionCommands.addCommandForGroup(id, "Request Wind", self.player[id].menu.waypoints.pname, self.ReportWind, self, id, pos, fname)
      missionCommands.addCommandForGroup(id, "Request Temperature", self.player[id].menu.waypoints.pname, self.ReportTemperature, self, id, pos, fname)
      missionCommands.addCommandForGroup(id, "Request BR", self.player[id].menu.waypoints.pname, self.ReportBR, self, id, pos, fname, self.player[id].unit)
    end
  end
  missionCommands.addCommandForGroup(id, "Request current AGL height", self.player[id].menu.aircraft, self.ReportHeight, self, id)
  --missionCommands.addCommandForGroup(ID, "Report AGL until touchdown", F10menu_ATC_airports[ID][name], start_timer, unit, "reportheight")
  --missionCommands.addCommandForGroup(ID, "Quit reporting AGL height", F10menu_ATC_airports[ID][name], stop_timer, unit, "reportheight")
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- Reporting Functions

--- Report pressure.
-- @param #PSEUDOATC self
-- @param #number id Group id to which the report is delivered.
-- @param #string Qcode Can be "QNH" for pressure at sea level or "QFE" for pressure at field elevation. Default is QFE or more precisely pressure at position.
-- @param Core.Point#COORDINATE position Coordinates at which the pressure is measured.
-- @param #string location Name of the location at which the pressure is measured.
function PSEUDOATC:ReportPressure(id, Qcode, position, location)

  -- Get pressure in hPa.  
  local P
  if Qcode=="QNH" then
    P=position:GetPressure(0)  -- Get pressure at sea level.
  else
    P=position:GetPressure()   -- Get pressure at (land) height of position.
  end
  
  -- Unit conversion.
  local P_inHg=P * PSEUDOATC.unit.hPa2inHg
  local P_mmHg=P * PSEUDOATC.unit.hPa2mmHg
 
  -- Message text. 
  local text=string.format("%s at %s: P = %.1f hPa = %.2 inHg = %.1f mmHg.", location, Qcode, P, P_inHg, P_mmHg)
  
  MESSAGE:New(text, 20):ToGroup(self.player[id].group)
  --trigger.action.outTextForGroup(ID, message, mlong)
  
end

--- Report temperature.
-- @param #PSEUDOATC self
-- @param #number id Group id to the report is delivered.
-- @param Core.Point#COORDINATE position Coordinates at which the pressure is measured.
-- @param #string location Name of the location at which the pressure is measured.
function PSEUDOATC:ReportTemperature(id, position, location)

  --- convert celsius to fahrenheit
  local function celsius2fahrenheit(degC)
    return degC*1.8+32
  end
 
  -- Get temperature at position in degrees Celsius. 
  local T=position:GetTemperature()
  
  -- Formatted temperature in Celsius and Fahrenheit.
  local Tc=string.format('%d°C', T)
  local Tf=string.format('%d°F', celsius2fahrenheit(T))
  
  -- Message text.  
  local text=string.format("Temperature at %s is %s = %s", location, Tc, Tf)
  
  -- Send message to player group.  
  MESSAGE:New(text, 20):ToGroup(self.player[id].group)
  --trigger.action.outTextForGroup(ID, message, mlong)
end

--- Report wind direction and strength.
-- @param #PSEUDOATC self
-- @param #number id Group id to the report is delivered.
-- @param Core.Point#COORDINATE position Coordinates at which the pressure is measured.
-- @param #string location Name of the location at which the pressure is measured.
function PSEUDOATC:ReportWind(id, position, location)

  -- Get wind direction and speed.
  local Dir,Vel=position:GetWind()
  
  -- Get Beaufort wind scale.
  local Bn,Bd=UTILS.BeaufortScale(Vel)
  
  -- Formatted wind direction.
  local Ds = string.format('%03d°', Dir)
  
  -- Message text.
  local text=string.format("Wind from %s at %.1f m/s (%s).", Ds, Vel, Bd)
    
  -- Send message to player group.  
  MESSAGE:New(text, 20):ToGroup(self.player[id].group)    
  --trigger.action.outTextForGroup(ID, message, mlong)
end

--- Report absolute bearing and range form player unit to airport.
-- @param #PSEUDOATC self
-- @param #number id Group id to the report is delivered.
-- @param Core.Point#COORDINATE position Coordinates at which the pressure is measured.
-- @param #string location Name of the location at which the pressure is measured.
function PSEUDOATC:ReportBR(id, position, location)

  --- Euclidean 2D distance between p and q (height is not considered here)
  local function distance2D(p,q)
    return math.sqrt((p.x-q.x)^2+(p.z-q.z)^2)
  end
  
  local function NorthCorrectionRadians(TargetVec3)
    local lat, lon = coord.LOtoLL(TargetVec3)
    local north_posit = coord.LLtoLO(lat + 1, lon)
    return math.atan2( north_posit.z - TargetVec3.z, north_posit.x - TargetVec3.x )
  end

  --- return direction in degrees
  local function direction2D(p)
    local dir= NorthCorrectionRadians(p) * 180 / math.pi
    if dir < 0 then
      dir = 360 + dir
    end
    return dir
  end

  --- norm of 2D vector
  local function abs2D(p)
    return math.sqrt((p.x)^2+(p.z)^2)
  end

  --- bearing and range from p to q (e.g. p=aircraft, q=airport)
  local function get_BR(p,q)
    local v={x=(q.x-p.x), y=(q.y-p.y), z=(q.z-p.z)}
    local bearing=direction2D(v)
    local range=abs2D(v)
    -- return bearing in degrees and range in km
    return bearing, range/1000
  end

  local p=get_position(unit)
  local p=self.player[id].unit:GetCoordinate()
  
  local b,r=get_BR(p, q)
  
  local bs = string.format( '%03d°', b)
   
  local mbr="Bearing "..bs..", Range "..round(r,1).." km = "..round(r*km2nm,1).." NM."
  
  local text=string.format("Bearing %s, Range %.1f km = %.1f NM.", Bs, r, r * PSEUDOATC.unit.km2nm)

  -- Send message to player group.  
  MESSAGE:New(text, 20):ToGroup(self.player[id].group)      
  trigger.action.outTextForGroup(ID, message, mlong)
end

--- Report height above ground level of player unit.
-- @param #PSEUDOATC self
-- @param #number id Group id to the report is delivered.
function PSEUDOATC:ReportHeight(id)
  local unit=self.player[id].unit --Wrapper.Unit#UNIT
  local position=unit:GetCoordinate()
  
  local height=get_AGL(position)
  local message="Your height is "..round(height,0).." m = "..round(height*meter2feet,0).." ft AGL."
  trigger.action.outTextForGroup(ID, message, mlong)
end

--------------------------------------------
