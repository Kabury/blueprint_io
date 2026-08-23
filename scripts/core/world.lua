---@param event EventData.on_script_trigger_effect
function on_bpio_created(event)
  if event.effect_id ~= "bpio-built-event" then return end
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

  local ids
  local section
  local building_inventory
  local in_inventory
  local out_inventory
  if not (core and building and input and output) then
    force.print("Something went wrong while building our entities. Remove everything and try again")
    return
  end
  
  ids = { core = core.unit_number, building =building.unit_number, input = input.unit_number, output = output.unit_number }
  if not (ids.core and ids.building and ids.input and ids.output) then return end 

  local sections = core.get_logistic_sections()
  if not sections then return end
  section = sections.get_section(1)
  if not section then return end
  section.set_slot(1,{value={type="virtual",name="signal-S",quality="normal"},min=1,max=1})
  section.set_slot(2,{value={type="virtual",name="signal-P",quality="normal"},min=0,max=0})
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
      output   = output
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
      force         = force,
      section       = section,
      statistics    = force.get_item_production_statistics(surface),
      progress_bars = {},
    },
    state =
    {
      status   = "off",
      check    = 0,
      checks   = {}, 
      lock     = false,
      progress = 0
    },
    sim = {},
    data = {}
  }
  for _,id in pairs(ids) do
    storage.dictionary.core[id]=core_dict
  end
  
  site.destroy()
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