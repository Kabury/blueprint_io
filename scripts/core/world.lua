---@param event EventData.on_script_trigger_effect
function on_bpio_created_or_wired(event)
  local built = event.effect_id == "bpio-built-event"
  local wired = event.effect_id == "bpio-wire-event"
  if not (built or wired) then return end
  if wired then 
    bpio_wire(event)
    return 
  end

  if not event.target_entity then return end
  local site = event.target_entity
  local surface = site.surface
  local position_x = site.position.x
  local position_y = site.position.y
  local force = site.force
  ---@cast force LuaForce

  local core
  local building
  local input
  local output
  local trigger
  if not (position_x and position_y) then return end
  
  core = surface.create_entity
  {
    name="bpio-core",
    position={x=position_x,y=position_y},
    force=force
  }
  building = surface.create_entity
  {
    name="bpio-core-building",
    position={x=position_x,y=position_y-6},
    force=force
  }
  input = surface.create_entity
  {
    name="bpio-core-input",
    position={x=position_x-6,y=position_y},
    force=force
  }
  output = surface.create_entity
  {
    name="bpio-core-output",
    position={x=position_x+5,y=position_y},
    force=force
  }
  trigger = surface.create_entity
  {
    name="bpio-land-mine",
    position={x=position_x,y=position_y},
    force=force
  }
  

  local ids
  local section
  local building_inventory
  local in_inventory
  local out_inventory
  if not (core and building and input and output and trigger) then
    force.print("Something went wrong while building our entities. Remove everything and try again")
    return
  end
  
  ids = { core = core.unit_number, building =building.unit_number, input = input.unit_number, output = output.unit_number, trigger = trigger.unit_number }
  if not (ids.core and ids.building and ids.input and ids.output and ids.trigger) then return end 

  
  local sections = core.get_logistic_sections()
  if not sections then return end
  section = sections.get_section(1)
  if not section then return end
  section.set_slot(1,{value={type="virtual",name="signal-S",quality="normal"},min=1,max=1})
  section.set_slot(2,{value={type="virtual",name="signal-P",quality="normal"},min=0,max=0})
  section.set_slot(3,{value={type="virtual",name="signal-dot",quality="normal"},min=0,max=0})
  section.set_slot(4,{value={type="virtual",name="shape-circle",quality="normal"},min=0,max=0})
  
  local trigger_behavior = trigger.get_or_create_control_behavior() 
  ---@cast trigger_behavior LuaLandMineControlBehavior
  local mine_red = trigger.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  local mine_green = trigger.get_wire_connector(defines.wire_connector_id.circuit_green,true)
  local core_red =  core.get_wire_connector(defines.wire_connector_id.circuit_red,true)
  local core_green = core.get_wire_connector(defines.wire_connector_id.circuit_green,true)
  if not (trigger_behavior and mine_red and mine_green and core_red and core_green) then return end

  mine_red.connect_to(core_red,false)
  mine_green.connect_to(core_green,false)
  
  
  trigger_behavior.circuit_enable_disable = true
  trigger_behavior.circuit_condition = {first_signal = {type="virtual",name="signal-dot",quality="normal"}, comparator = "!=", constant=0}

  building_inventory = building.get_inventory(defines.inventory.chest)
  in_inventory  = input.get_inventory(defines.inventory.chest)
  out_inventory = output.get_inventory(defines.inventory.chest)
  if not (building_inventory and in_inventory and out_inventory) then return end

  local core_dict =
  {
    ids = ids,
    ent =
    {
      core     = core,
      building = building,
      input    = input,
      output   = output,
      trigger  = trigger
    },
    inv =
    {
      blueprint = game.create_inventory(1),
      building  = building_inventory, 
      input     = in_inventory,
      output    = out_inventory
    },
    aux = 
    {
      surface       = surface,
      surface_index = surface.index,
      properties    = {},
      rendering     = rendering.draw_animation{animation="bpio-item-extractor-off",target=core,surface=surface},
      render_name   = "bpio-item-extractor",
      position      = { x = position_x, y = position_y},
      projector_direction = "right-top",
      force         = force,
      section       = section,
      statistics    = force.get_item_production_statistics(surface),
      progress_bars = {},
    },
    state =
    {
      status     = "off",
      check      = 0,
      checks     = {},
      check_info = { amount=4, time=30 },
      lock       = false,
      progress   = 0
    },
    sim = {},
    data = {}
  }
  for _,id in pairs(ids) do
    storage.dictionary.core[id]=core_dict
  end
  site.destroy()
end


function bpio_wire(event)
  if not event.target_entity then return end
  
  local wtrigger = event.target_entity
  ---@type coreDict
  local wcore = storage.dictionary.core[wtrigger.unit_number]
  if not wcore then return end

  
  local new_trigger = wcore.aux.surface.create_entity
  {
    name="bpio-land-mine",
    position={x=wcore.aux.position.x,y=wcore.aux.position.y},
    force=wcore.aux.force
  } --[[@as LuaSurface.create_entity_param.land_mine]]
  if not new_trigger then return end
  storage.dictionary.core[wtrigger.unit_number]=nil
  wtrigger.destroy()
  wcore.ent.trigger = new_trigger
  wcore.ids.trigger = new_trigger.unit_number
  storage.dictionary.core[new_trigger.unit_number]=wcore

  local new_trigger_behavior = new_trigger.get_or_create_control_behavior() 
  ---@cast new_trigger_behavior LuaLandMineControlBehavior
  local new_mine_red = new_trigger.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local new_mine_green = new_trigger.get_wire_connector(defines.wire_connector_id.circuit_green, true)
  local wcore_red =  wcore.ent.core.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local wcore_green = wcore.ent.core.get_wire_connector(defines.wire_connector_id.circuit_green, true)
  if not (new_trigger_behavior and new_mine_red and new_mine_green and wcore_red and wcore_green) then return end

  new_mine_red.connect_to(wcore_red,false)
  new_mine_green.connect_to(wcore_green,false)
  
  new_trigger_behavior.circuit_enable_disable = true

  local new_listen
  if wcore.state.status == "off" or wcore.state.status == "booting" then
    wcore.aux.force.print("You tried to activate a core when it was not possible to do so.")
    new_listen = wcore.aux.section.get_slot(3).value
  elseif wcore.state.status == "standby" then
    wcore.aux.force.print("Circuit on")
    bpio_on(wcore,event)
    new_listen = wcore.aux.section.get_slot(4).value
  elseif wcore.state.status == "on" then
    wcore.aux.force.print("Circuit off")
    bpio_standby(wcore)
    new_listen = wcore.aux.section.get_slot(3).value
  end

  new_trigger_behavior.circuit_condition = {first_signal = new_listen, comparator = "!=", constant=0} --[[@as CircuitConditionDefinition]]
end


---@param event EventData.on_player_mined_entity|EventData.on_robot_mined_entity
function on_bpio_mined(event)
  if not event.entity then return end
  local name = event.entity.name
  local is_core = name == "bpio-core"
  local is_aide = name == "bpio-core-building" or name == "bpio-core-input" or name == "bpio-core-output"
  if not (is_core or is_aide) then return end

  ---@type coreDict
  local core = storage.dictionary.core[event.entity.unit_number]
  if not (core and is_valid_core(core,"both")) then return end

  if is_aide then
    event.buffer.insert({name = "bpio-site", count = 1})
  end

  for _,inventory in pairs(core.inv) do
    event.buffer.transfer_from_inventory(inventory)
  end

  gui_kick_everyone(core)
  if core.state.sim_lock then surface_recall(core) end
  core_destroy(core)
end



---@param event EventData.on_entity_died
function on_bpio_killed(event)
  local entity = event.entity
  if not entity then return end

  local core = storage.dictionary.core[entity.unit_number]
  if not (core and is_valid_core(core,"both")) then return end

  gui_kick_everyone(core)
  if core.state.sim_lock then surface_shutdown(core) end
  core_die(core)
end