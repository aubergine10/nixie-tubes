require "config"

-- luacheck: globals refresh_rate global game defines script

local ticksPerRefresh = math.ceil(60 / refresh_rate)

local function removeSpriteObjs(nixie)
  for _,obj in pairs(global.spriteobjs[nixie.unit_number]) do
    if obj.valid then
      if obj.passenger then
        obj.passenger.destroy()
      end
      obj.clear_items_inside()
      obj.destroy()
    end
  end
end

local smallstep=1/12
local bigstep=1/40
--build LuT to convert states into orientation values.
local stateOrientMap = {
  { -- state map for big nixies
  -- A straight count *should* work here but doesn't. Maybe one day I'll figure out why...
  ["0"]=bigstep*0,
  ["1"]=bigstep*1,
  ["2"]=bigstep*2.5,
  ["3"]=bigstep*3.5,
  ["4"]=bigstep*4.7,
  ["5"]=bigstep*5.7,
  ["6"]=bigstep*6.7,
  ["7"]=bigstep*7.5,
  ["8"]=bigstep*8.5,
  ["9"]=bigstep*9,
  ["A"]=bigstep*10,
  ["B"]=bigstep*11,
  ["C"]=bigstep*11.5,
  ["D"]=bigstep*12,
  ["E"]=bigstep*13,
  ["F"]=bigstep*14,
  ["G"]=bigstep*15,
  ["H"]=bigstep*16,
  ["I"]=bigstep*17,
  ["J"]=bigstep*19,
  ["K"]=bigstep*20,
  ["L"]=bigstep*21,
  ["M"]=bigstep*22.5,
  ["N"]=bigstep*23.5,
  ["O"]=bigstep*24.7,
  ["P"]=bigstep*25.7,
  ["Q"]=bigstep*26.7,
  ["R"]=bigstep*27.5,
  ["S"]=bigstep*28.5,
  ["T"]=bigstep*29,
  ["U"]=bigstep*30,
  ["V"]=bigstep*31,
  ["W"]=bigstep*31.5,
  ["X"]=bigstep*32,
  ["Y"]=bigstep*33,
  ["Z"]=bigstep*34,
  ["err"]=bigstep*35,
  ["dot"]=bigstep*36,
  ["minus"]=bigstep*37,
  ["off"]=bigstep*38,

  },
  { -- state map for small nixies
  ["off"]=smallstep*0,
  ["0"]=smallstep*1,
  ["1"]=smallstep*2,
  ["2"]=smallstep*3,
  ["3"]=smallstep*4,
  ["4"]=smallstep*5,
  ["5"]=smallstep*6,
  ["6"]=smallstep*7,
  ["7"]=smallstep*8,
  ["8"]=smallstep*9,
  ["9"]=smallstep*10,
  ["minus"]=smallstep*11,
  },
}

local signalCharMap = {
  ["signal-0"] = "0",
  ["signal-1"] = "1",
  ["signal-2"] = "2",
  ["signal-3"] = "3",
  ["signal-4"] = "4",
  ["signal-5"] = "5",
  ["signal-6"] = "6",
  ["signal-7"] = "7",
  ["signal-8"] = "8",
  ["signal-9"] = "9",
  ["signal-A"] = "A",
  ["signal-B"] = "B",
  ["signal-C"] = "C",
  ["signal-D"] = "D",
  ["signal-E"] = "E",
  ["signal-F"] = "F",
  ["signal-G"] = "G",
  ["signal-H"] = "H",
  ["signal-I"] = "I",
  ["signal-J"] = "J",
  ["signal-K"] = "K",
  ["signal-L"] = "L",
  ["signal-M"] = "M",
  ["signal-N"] = "N",
  ["signal-O"] = "O",
  ["signal-P"] = "P",
  ["signal-Q"] = "Q",
  ["signal-R"] = "R",
  ["signal-S"] = "S",
  ["signal-T"] = "T",
  ["signal-U"] = "U",
  ["signal-V"] = "V",
  ["signal-W"] = "W",
  ["signal-X"] = "X",
  ["signal-Y"] = "Y",
  ["signal-Z"] = "Z",
  ["fast-splitter"] = "minus",
  ["train-stop"] = "dot",
}

local signalColorMap = {
  ["signal-red"]={r=1,g=0,b=0,a=0.3},
  ["signal-green"]={r=0,g=1,b=0,a=0.3},
  ["signal-blue"]={r=0,g=0,b=1,a=0.3},
  ["signal-yellow"]={r=1,g=1,b=0,a=0.3},
  ["signal-pink"]={r=1,g=0,b=1,a=0.3},
  ["signal-cyan"]={r=0,g=1,b=1,a=0.3},
}

--sets the state(s) and update the sprite for a nixie
local function setStates(nixie,newstates,color)
  for key,new_state in pairs(newstates) do
    local obj = global.spriteobjs[nixie.unit_number][key]
    if obj and obj.valid then
      if nixie.energy > 70 then
        obj.orientation=stateOrientMap[#newstates][new_state]
        if color and new_state ~= "off" then
          -- create and color a passenger
          if not obj.passenger then
            obj.passenger = obj.surface.create_entity{name="player", position=obj.position,force=obj.force}
          end
          obj.passenger.color=color
        else
          -- destroy the passenger to get basic-orange
          if obj.passenger then
            obj.passenger.destroy()
          end
        end
      else
        obj.orientation=stateOrientMap[#newstates]["off"]
      end
    else
      game.players[1].print("invalid nixie?")
    end
  end
end

-- from binbinhfr/SmartDisplay, modified to check both wires and add them
local function get_signal_value(entity)
	local behavior = entity.get_control_behavior()
	if behavior == nil then	return(nil)	end

	local condition = behavior.circuit_condition
	if condition == nil then return(nil) end

	local signal = condition.condition.first_signal

	if signal == nil or signal.name == nil then return(nil)	end

	local redval,greenval=0,0

	local network = entity.get_circuit_network(defines.wire_type.red)
	if network then
	  redval = network.get_signal(signal)
	end

	network = entity.get_circuit_network(defines.wire_type.green)
	if network then
	  greenval = network.get_signal(signal)
	end


	local val = redval + greenval

	return(val)
end

local function searchbox(nixie,direction)
  local offset = direction=="right" and 1 or -1
  return {
    {nixie.position.x+offset-0.1,nixie.position.y-0.1},
    {nixie.position.x+offset+0.1,nixie.position.y+0.1}
    }
end

local validEntityName = {
  ['nixie-tube']       = 1,
  ['nixie-tube-alpha'] = 1,
  ['nixie-tube-small'] = 2
}

local function onPlaceEntity(event)

  local entity=event.created_entity
  if not entity.valid then return end

  local num = validEntityName[entity.name]
  if num then
    local pos=entity.position
    local surf=entity.surface

    local sprites = {}
    for n=1, num do
      --place the /real/ thing(s) at same spot
      local name, position
      if num == 1 then -- large tube, one sprite
        name = "nixie-tube-sprite"
        position = {x=pos.x+1/32, y=pos.y+1/32}
      else
        name = "nixie-tube-small-sprite"
        position = {x=pos.x-4/32+((n-1)*10/32), y=pos.y+4/32}
      end
      local sprite=surf.create_entity(
        {
              name=name,
              position=position,
            force=entity.force
        })
      sprite.orientation=0
      sprite.insert({name="coal",count=1})
      sprites[n]=sprite
    end
    global.spriteobjs[entity.unit_number] = sprites

    if entity.name == "nixie-tube-alpha" then
      global.alphas[entity.unit_number] = entity
    else
      --enslave guy to left, if there is one
      local neighbors=surf.find_entities_filtered{area=searchbox(entity,"left"),name=entity.name}
      for _,n in pairs(neighbors) do
        if n.valid then
          global.controllers[n.unit_number] = nil
          global.nextdigit[entity.unit_number] = n
        end
      end


      --slave self to right, if any
      neighbors=surf.find_entities_filtered{area=searchbox(entity,"right"),name=entity.name}
      local foundright=false
      for _,n in pairs(neighbors) do
        if n.valid then
          foundright=true
          global.nextdigit[n.unit_number]=entity
        end
      end
      if not foundright then
        global.controllers[entity.unit_number] = entity
      end
    end
  end
end

local function displayBlank(entity)
  local nextdigit = global.nextdigit[entity.unit_number]

  setStates(entity,(#global.spriteobjs[entity.unit_number]==1) and {"off"} or {"off","off"})
  if nextdigit and nextdigit.valid then
    displayBlank(nextdigit)
  end
end

local function displayMinus(entity)
  local nextdigit = global.nextdigit[entity.unit_number]

  setStates(entity,(#global.spriteobjs[entity.unit_number]==1) and {"minus"} or {"off","minus"})
  if nextdigit and nextdigit.valid then
    displayBlank(nextdigit)
  end
end


local function displayValue(entity,v)
  local minus=v<0
  if minus then v=-v end
  local nextdigit = global.nextdigit[entity.unit_number]

  if #global.spriteobjs[entity.unit_number] == 1 then
    local m=v%10
    v=(v-m)/10
    local state = tostring(m)
    setStates(entity,{state})
    if nextdigit and nextdigit.valid then
      if v == 0 and minus then
        displayMinus(nextdigit)
      elseif minus then
        displayValue(nextdigit,-v)
      elseif v == 0 then
        displayBlank(nextdigit)
      else
        displayValue(nextdigit,v)
      end
    end
  else
    local m=v%100 -- two digits for this pair of nixies
    v=(v-m)/100 -- remove two digits from what's left
    local n=m%10 -- ones digit for this pair
    m=(m-n)/10 -- tens digit for this pair
    local state1
    local state2 = tostring(n)
    if m>0 or v>0 then
      state1 = tostring(m)
    elseif minus then
      state1 = "minus"
      minus = nil
    else
      state1 = "off"
    end
    setStates(entity,{state1,state2})

    if nextdigit and nextdigit.valid then
      if v == 0 and minus then
        displayMinus(nextdigit)
      elseif minus then
        displayValue(nextdigit,-v)
      elseif v == 0 then
        displayBlank(nextdigit)
      else
        displayValue(nextdigit,v)
      end
    end
  end
end

local function onTickController(entity)
  if not entity.valid then
    onRemoveEntity(entity)
    return
  end

  -- local open=false
  for _,v in pairs(game.players) do
    if v.opened==entity then return end
  end

  local v=get_signal_value(entity)
  if v then
    displayValue(entity,v)
  else
    displayBlank(entity)
  end
end


local function getAlphaSignals(entity,wire_type,charsig,colorsig)
  local net = entity.get_circuit_network(wire_type)

  local ch,co = charsig,colorsig

  if net then
    for _,s in pairs(net.signals) do
      if signalCharMap[s.signal.name] then
        if ch then
          ch = "err"
        else
          ch = signalCharMap[s.signal.name]
        end
      end
      if signalColorMap[s.signal.name] then
        co = signalColorMap[s.signal.name]
      end
    end
  end

  return ch,co
end

local function onTickAlpha(entity)
  if not entity then return end

  if not entity.valid then
    onRemoveEntity(entity)
    return
  end

  --local open=false
  for _,v in pairs(game.players) do
    if v.opened==entity then return end
  end

  local charsig,colorsig = nil,nil

  charsig,colorsig=getAlphaSignals(entity,defines.wire_type.red,charsig,colorsig)
  charsig,colorsig=getAlphaSignals(entity,defines.wire_type.green,charsig,colorsig)
  charsig = charsig or "off"
  setStates(entity,{charsig},colorsig)
end


local function onTick(event)
  if event.tick%ticksPerRefresh == 0 then
    for _,nixie in pairs(global.controllers) do
      onTickController(nixie)
    end
  -- end
  -- if event.tick%ticksPerRefresh == 0 then
    for _,nixie in pairs(global.alphas) do
      onTickAlpha(nixie)
    end
  end
end


local function onRemoveEntity(entity)
  if entity.valid then
    if validEntityName[entity.name] then
      removeSpriteObjs(entity)
      --if I was a controller, deregister
      global.controllers[entity.unit_number]=nil
      --if i was an alpha, deregister
      global.alphas[entity.unit_number]=nil
      --if I had a next-digit, register it as a controller
      local nextdigit = global.nextdigit[entity.unit_number]
      if nextdigit and nextdigit.valid then
        global.controllers[nextdigit.unit_number] = nextdigit
        displayBlank(nextdigit)
      end
    end
  end
end

script.on_init(function()
  global.alphas = {}
  global.controllers = {}
  global.spriteobjs = {}
  global.nextdigit = {}
end)


script.on_configuration_changed(function(data)
  if data.mod_changes and data.mod_changes["nixie-tubes"] then
    if not global.alphas then global.alphas = {} end
    if global.nixie_tubes then
      global.controllers = {}
      global.spriteobjs = {}
      global.nextdigit = {}
      for _,surf in pairs(global.nixie_tubes.nixies) do
        for _,row in pairs(surf) do
          for _,desc in pairs(row) do
            if desc.entities[1] and desc.entities[1].valid then
              for _,s in pairs(desc.spriteobjs) do if s.valid then s.clear_items_inside() s.destroy() end end
              onPlaceEntity({created_entity=desc.entities[1]})
            end
          end
        end
      end
      global.nixie_tubes = nil
    end
  end
end)

script.on_event(defines.events.on_built_entity, onPlaceEntity)
script.on_event(defines.events.on_robot_built_entity, onPlaceEntity)

script.on_event(defines.events.on_preplayer_mined_item, function(event) onRemoveEntity(event.entity) end)
script.on_event(defines.events.on_robot_pre_mined, function(event) onRemoveEntity(event.entity) end)
script.on_event(defines.events.on_entity_died, function(event) onRemoveEntity(event.entity) end)

script.on_event(defines.events.on_tick, onTick)

script.on_event(defines.events.on_player_driving_changed_state,
    function(event)
      local player=game.players[event.player_index]
      if player.vehicle and
        (player.vehicle.name=="nixie-tube-sprite" or
          player.vehicle.name=="nixie-tube-small-sprite") then
        player.vehicle.passenger=nil
      end
    end
  )
