---@param plan BlueprintInsertPlan
---@param entity LuaEntity
---@param memory planMemory
function begin_plan(plan,entity,memory)
  if not entity.unit_number then return end
  local item_name = plan.id.name
  local quality = plan.id.quality
  if quality == nil then quality = "normal" end

  local position = plan.items

  if position.in_inventory then
    for _, place in pairs(position.in_inventory) do
      local inventory = entity.get_inventory(place.inventory)
      if inventory then
        local entityInventories = kl.get_or_set(memory.places.inventory,entity.unit_number)
        entityInventories[place.inventory] = inventory
        local stack = inventory[place.stack + 1] --[[@as LuaItemStack]]
        if stack and not stack.valid_for_read then
          local item_format = { name = item_name,  count = place.count or 1,  quality = quality }
          stack.set_stack(item_format)
          memory.beggining[#memory.beggining+1] = item_format
          if entity.name == "bpio-blueprintable-output" then 
            memory.beggining[#memory.beggining+1] = item_format 
          end
        end
      end
    end
  end

  if position.grid_count and position.grid_count > 0 then
    local grid = entity.grid
    if grid then
      memory.places.grids[entity.unit_number] = grid
      for i = 1, position.grid_count do
        local item_format = { name = item_name,  count = 1,  quality = quality }
        grid.put(item_format)
        memory.beggining[#memory.beggining+1] = item_format
      end
    end
  end
end



---@param memory planMemory
function end_plan(memory)

  for _,entity in pairs(memory.places.inventory) do
    for _,inventory in pairs(entity) do
      if inventory.valid then
        local item_array = inventory.get_contents()
        for _,item_format in pairs(item_array) do
          memory.ending[#memory.ending+1] = item_format --[[@as ItemStackDefinition]]
        end
      end
    end
  end

  for _,grid in pairs(memory.places.grids) do
    local item_array = grid.get_contents()
    for _,item_format in pairs(item_array) do
      memory.ending[#memory.ending+1] = item_format --[[@as ItemStackDefinition]]
    end
  end

end



---@param core coreDict
function bpio_boot(core,event)
  local every_force = game.forces
  if #every_force > 56 then
    core.aux.force.print("Wait until a few forces have been freed up")
    return
  end

  local is_valid_blueprint, target_size = validate_blueprint(core)
  if not (is_valid_blueprint and target_size and target_size.x and target_size.y) then return end

  local building_inventory = core.inv.building
  local building_wants = core.inv.blueprint[1].cost_to_build --[[@as ItemStackDefinition[] ]]
  local building_has = building_inventory.get_contents() --[[@as ItemStackDefinition[] ]]
  local building_error = false

  local wants_list = as_item_list(building_wants)
  local has_list = as_item_list(building_has)
  
  if not (wants_list["bpio-blueprintable-input"] and 
          wants_list["bpio-blueprintable-input"].normal == 1 and 
          wants_list["bpio-blueprintable-output"] and 
          wants_list["bpio-blueprintable-output"].normal == 1) then
    core.aux.force.print("Your blueprint has to have a single input and a single output")
    return
  end

  if is_super_set(has_list,wants_list) then
    for _,item_format in pairs(building_wants) do
      local removed = building_inventory.remove(item_format)
      if removed ~= item_format.count then building_error = true end
    end
  else
    core.aux.force.print("You don't have enough items to build this blueprint")
    return
  end


  if building_error then
    core.aux.force.print("There was an error while building the core. Unsure what happened. Proceeding normally...")
  else
    core.aux.force.print("Used items needed to build")
  end 

  core.aux.section.set_slot(1,{min=2,max=2,value=core.aux.section.get_slot(1).value})
  for _,property in pairs(prototypes.surface_property) do
    core.aux.properties[property] = core.aux.surface.get_property(property)
  end

  core.state.status = "booting"
  core.state.check = 0
  core.state.sim_lock = "build_ghosts"
  core.state.progress = 0

  local name = "bpio-"..tostring(core.ids.core)
  
  target_size.x = target_size.x + 8
  target_size.y = target_size.y + 8 
  core.sim.surface = game.create_surface(name,{width=target_size.x,height=target_size.y})
    for property,value in pairs(core.aux.properties) do
    core.sim.surface.set_property(property,value)
  end
  core.sim.surface.generate_with_lab_tiles = true
  core.sim.surface.request_to_generate_chunks({0,0},math.max(math.ceil(target_size.x/32),math.ceil(target_size.y/32)))
  core.sim.surface.force_generate_chunk_requests()
  core.sim.force = game.create_force(name)
  core.sim.force.copy_from(core.aux.force)
  core.sim.size = target_size
  core.sim.plan_memory = { places = { inventory = {}, grids = {} }, beggining = {}, ending = {} }

  core.data.cost = building_wants
  core.data.input = core.inv.input.get_contents() --[[@as ItemStackDefinition[] ]]
  core.data.input_list = as_item_list(core.data.input)
  core.data.history = {}

  core.aux.force.print("Created surface and force")
  local time_slice = kl.get_or_set(storage.queue,event.tick+1)
  time_slice[#time_slice+1]=core.ids.core
  redraw_everyone(core)
end



---@param core coreDict
function bpio_off(core)
  core.aux.section.set_slot(2,{value=core.aux.section.get_slot(2).value,min=0,max=0})
  core.aux.section.set_slot(1,{min=1,max=1,value=core.aux.section.get_slot(1).value})

  core.state.status = "off"
  core.state.check = 0
  core.state.checks = {}
  
  for _,item_format in pairs(core.data.cost) do
    core.inv.building.insert(item_format)
  end
  core.data =
  {
    pollution   = 0,
    cost        = {},
    input       = {},
    output      = {},
    input_list  = {},
    output_list = {},
    history     = {}
  }

  redraw_everyone(core)  
end



---@param event EventData.on_gui_click
function handle_buttons(event)
  local start_boot = event.element.name == "bpio-start-boot"
  local turn_off = event.element.name == "bpio-turn-off"
  local turn_on = event.element.name == "bpio-turn-on"
  local to_standby = event.element.name == "bpio-to-standby"
  if not (start_boot or turn_off or turn_on or to_standby) then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local dicts = storage.dictionary
  if not dicts then return end
  local id_core = dicts.player[player.index]

  ---@type coreDict
  local core = dicts.core[id_core]
  if not is_valid_core(core,"both") then
    core.aux.force.print("Invalid core")
    return
  end

  if start_boot then
    bpio_boot(core,event)

  elseif turn_off then
    bpio_off(core)

  elseif turn_on then
    core.aux.section.set_slot(1,{min=4,max=4,value=core.aux.section.get_slot(1).value})
    core.state.status = "on"
    core.state.checks = {"?","?","?","?"}
    
    local time_slice = kl.get_or_set(storage.queue,event.tick+1)
    time_slice[#time_slice+1] = core.ids.core

    redraw_everyone(core)
  elseif to_standby then
    core.aux.section.set_slot(1,{min=3,max=3,value=core.aux.section.get_slot(1).value})
    core.state.status = "standby"
    core.state.checks = {}
    core.state.check = 0

    redraw_everyone(core)
  end
end