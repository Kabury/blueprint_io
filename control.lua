--=================
--===== Types =====
--=================

---@class coreEntities
---@field core LuaEntity The core entity with the controlling GUI
---@field input LuaEntity The in interface
---@field output LuaEntity The out interface

---@class coreInventories
---@field blueprint LuaInventory Inventory for the blueprint slot
---@field building LuaInventory Inventory for the buildings for the blueprint
---@field input LuaInventory Inventory to check incoming items. Tied to the entity
---@field output LuaInventory Inventory to check outgoing items. Tied to the entity
---@field history LuaInventory[] All the inventories at different times in the core

---@class coreDict
---@field id coreID
---@field entities coreEntities
---@field inventories coreInventories
---@field state "off"|"booting"|"standby"|"on"
---@field check number Check number
---@field cost ItemWithQualityCount[] How much did it cost to activate this core.
---@field input ItemWithQualityCount[] What will be spawned in the blueprint
---@field input_list itemList Pre-processed inputs for comparison
---@field history ItemWithQualityCount[] Lists of items at different times of the surface
---@field history_lists itemList[] Lists of items at different times of the surface
---@field output ItemWithQualityCount[] What will be spanwed in the interface

---@class surfaceDict
---@field core coreDict The core associated to the surface
---@field status string? What stage the surface is on
---@field lua LuaSurface The lua pointer to the surface
---@field force LuaForce The lua pointer to the temporary force
---@field building_force LuaForce The building force
---@field properties table<LuaSurfacePropertyPrototype,double> The building surface's properties. Stored so our new surface can copy them later.
---@field size TilePosition Size of the blueprint
---@field input_watcher LuaEntity
---@field output_watcher LuaEntity
---@field ghosts LuaEntity[] The ghosts we build
---@field progress double How much has the surface ran
---@field progress_bars LuaGuiElement[] The progress bar

---@alias playerID uint32

---@class dictionaryDict
---@field core table<coreID,coreDict>
---@field surface surfaceDict
---@field player table<playerID,coreID>

---@alias time number
---@alias coreID number
---@alias status "build_ghosts"|"begin_entities"|"retry_entities"|"initialize_inventories"|"begin_logging"|"busy"|"epilog"

---@class queueDict
---@field core table<time, coreID[]>
---@field surface table<time, status>

---@alias quality_name string
---@alias qualityCounts table<quality_name,number>
---@alias itemList table<data.ItemName,qualityCounts>

--==========================
--===== Initialization =====
--==========================

local function init_storage()
  storage.dictionary = { surface = {}, core = {}, player = {} }
  storage.queue = { surface = {}, core = {} }
end

script.on_init(function()
  init_storage()
end)

local function reorganize(event)
  if event.setting == "bpio-stagger" then 
  end
end

script.on_event(defines.events.on_runtime_mod_setting_changed, reorganize)



--===================
--===== Library =====
--===================

local TILE_RESOLUTION = 32

local kl = require("__klib__.runtime_stage")

---@param item_array ItemWithQualityCount[]
local function as_item_list(item_array)
  ---@type itemList
  local item_list = {}
  for _,item_format in pairs(item_array) do
    local item_table = kl.get_or_set(item_list,item_format.name)
    item_table[item_format.quality] = item_table[item_format.quality] or 0 + item_format.count
  end
  return item_list
end

---@param item_list itemList
local function as_item_quality_count(item_list)
  ---@type ItemWithQualityCount[]
  local item_table = {}
  for name,qcounts in pairs(item_list) do
    for quality,count in pairs(qcounts) do
      if count < 0 then
        table.insert(item_table,{name=name,quality=quality,count=-count})
      elseif count > 0 then
        table.insert(item_table,{name=name,quality=quality,count=count})
      end
    end
  end
  return item_table
end

---@param super_list itemList
---@param sub_list itemList
local function is_super_set(super_list,sub_list)
  for name,qcounts in pairs(sub_list) do
    if not super_list[name] then return false end
    for quality,count in pairs(qcounts) do
      if not super_list[name][quality] then return false end
      if count > super_list[name][quality] then return false end
    end
  end
  return true
end

---@param before itemList
---@param after itemList
local function items_consumed(before,after)
  local difference = {}
	for name,qcounts in pairs(before) do
    difference[name] = {}
    if not after[name] then after[name] = {} end
    for quality,count in pairs(qcounts) do
      difference[name][quality] = count - (after[name][quality] or 0)
    end
	end
  return difference
end

---@param dict coreDict
---@param mode "entities"|"inventories"|"both"
local function is_valid_core(dict,mode)
  if not dict then return false end
  local entities_check = true
  if mode == "entities" or mode == "both" then
    for _,entity in pairs(dict.entities) do
      entities_check = entities_check and entity.valid
    end
  end

  local inventories_check = true
  if mode == "inventories" or mode == "both" then
    for type,inventory in pairs(dict.inventories) do
      if type == "history" then
        for _,inner_inventory in pairs(inventory) do
          inventories_check = inventories_check and inner_inventory.valid
        end
      else  
        inventories_check = inventories_check and inventory.valid   
      end
    end
  end

  return entities_check and inventories_check
end

---@param dict coreDict
local function core_destroy(dict)
  dict.inventories.blueprint.destroy()
  dict.inventories.building.destroy()
  dict.entities.output.die()
  dict.entities.input.die()
  dict.entities.core.die()
end

local function nil_surface_data()
  local data = storage.dictionary.surface
  data.core = nil
  data.status = nil
  data.lua = nil
  data.force = nil
  data.building_force = nil
  data.properties = nil
  data.size = nil
  data.ghosts = nil
  data.progress = nil
  data.progress_bars = nil
  storage.queue.surface = {}
end

---@param dict surfaceDict
local function surface_shutdown(dict)
  game.delete_surface("bpio-surface")
  game.merge_forces("bpio-force",dict.building_force)
  local force = dict.core.entities.core.force --[[@as LuaForce]]
  force.print("Shutting dimension down")
  nil_surface_data()
end

---@param dict surfaceDict
local function surface_recall(dict)
  game.delete_surface("bpio-surface")
  game.merge_forces("bpio-force",dict.building_force)
  local core = dict.core
  local building_inventory = core.inventories.building
  for _,item_format in pairs(core.cost) do
    building_inventory.insert(item_format)
  end
  local force= core.entities.core.force --[[@as LuaForce]]
  force.print("Refunded buildings")
  nil_surface_data()
end

--===== Functions for GUI

---@param player LuaPlayer
---@param core_dict coreDict
local function draw_gui(player,core_dict)
  local valid = is_valid_core(core_dict,"both")
  if not valid then 
    core_destroy(core_dict) 
    return
  end

  if player.gui.screen["bpio-menu"] then
    player.gui.screen["bpio-menu"].destroy()
  end

  local gui = {}
  gui.master = player.gui.screen.add{
    type = "frame",
    name = "bpio-menu",
    caption = { "gui-element.bpio-gui-title" },
    style = "inset_frame_container_frame",
    direction = "vertical"
  }
  gui.pane_space = gui.master.add{
    type="flow",
    direction="horizontal"
  }
  gui.panes={}
  gui.master.auto_center = true
  player.opened = gui.master


  if core_dict.state == "booting" then
    gui.panes.booting = {} 
    gui.panes.booting.frame = gui.pane_space.add{
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical"
    }
    gui.panes.booting.label = gui.panes.booting.frame.add{
      type = "label",
      caption = {"gui-element.bpio-status-booting-label"},
      style = "frame_title"
    }
    gui.panes.booting.surface_label = gui.panes.booting.frame.add{
      type = "label",
      caption = {"gui-element.bpio-booting-surface-label",core_dict.entities.core.surface.name:gsub("^%l", string.upper)}
    }


    gui.panes.booting.preview_frame = gui.panes.booting.frame.add{
      type = "frame",
      style = "deep_frame_in_shallow_frame"
    }

    ---@type surfaceDict
    local surface = storage.dictionary.surface
    local res = player.display_resolution 
    local target_zoom
    if surface.size.x and surface.size.y then 
      local zoom_x = (res.width-350) / (surface.size.x * TILE_RESOLUTION)
      local zoom_y = (res.height-350) / (surface.size.y * TILE_RESOLUTION)
      target_zoom = math.min(zoom_x, zoom_y)
    else
      target_zoom = 1
    end

    gui.panes.booting.bpio_surface = gui.panes.booting.preview_frame.add{
      type = "camera",
      position = {0,0},
      surface_index = surface.lua.index,
      zoom = target_zoom
    }
    
    gui.panes.booting.bpio_surface.style.natural_width = res.width - 300
    gui.panes.booting.bpio_surface.style.natural_height = res.height - 300
    
    gui.panes.booting.bar_flow = gui.panes.booting.frame.add{
      type="flow",
      direction="horizontal"
    }
    gui.panes.booting.bar_space = gui.panes.booting.bar_flow.add{
      type="empty-widget"
    }
    gui.panes.booting.bar_space.style.natural_width = (res.width - 300)/3
    gui.panes.booting.progress_bar = gui.panes.booting.bar_flow.add{
      type="progressbar"
    }
    gui.panes.booting.progress_bar.style.natural_width = (res.width - 300)/3
    gui.panes.booting.progress_bar.style.bar_width = 12
    surface.progress_bars[player.index] = gui.panes.booting.progress_bar

  else
    gui.panes.player={}
    gui.panes.player.frame = gui.pane_space.add{
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical"
    }
    gui.panes.player.flow = gui.panes.player.frame.add{
      type = "flow",
      style = "two_module_spacing_vertical_flow",
      direction = "vertical"
    }
    gui.panes.player.label = gui.panes.player.flow.add{
      type = "label",
      caption = {"gui-element.bpio-player-label"}
    }
    gui.panes.player.inventory = gui.panes.player.flow.add{
      type = "inventory",
      slots_per_row = prototypes.utility_constants.inventory_width
    }
    local player_inventory = player.get_main_inventory()
    gui.panes.player.inventory.inventory = player_inventory


    gui.panes.control = {} 
    gui.panes.control.frame = gui.pane_space.add{
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical"
    }
    gui.panes.control.label = gui.panes.control.frame.add{
      type = "label",
      caption = {"gui-element.bpio-control-label"},
      style = "frame_title"
    }

    gui.panes.control.preview_frame = gui.panes.control.frame.add{
      type = "frame",
      style = "deep_frame_in_shallow_frame"
    }
    gui.panes.control.preview = gui.panes.control.preview_frame.add{
      type = "camera",
      position = core_dict.entities.core.position,
      surface_index =  core_dict.entities.core.surface_index,
      zoom = 0.65
    }
    gui.panes.control.preview.style.natural_height=200
    gui.panes.control.preview.style.natural_width=400

    gui.panes.control.surface_label = gui.panes.control.frame.add{
      type = "label",
      caption = {"gui-element.bpio-control-surface-label",core_dict.entities.core.surface.name:gsub("^%l", string.upper)}
    }


    if core_dict.state == "off" then
      gui.panes.control.status_label = gui.panes.control.frame.add{
        type = "label",
        caption = {"gui-element.bpio-status-off-label"}
      }
      gui.panes.control.button = gui.panes.control.frame.add{
        type = "sprite-button",
        name = "bpio-simulate",
        sprite = "utility/play",
        style = "train_schedule_action_button"
      }
    end

    if core_dict.state == "standby" then
      gui.panes.control.status_label = gui.panes.control.frame.add{
        type = "label",
        caption = {"gui-element.bpio-status-standby-label"}
      }
      gui.panes.control.button = gui.panes.control.frame.add{
        type = "sprite-button",
        name = "bpio-simulate",
        sprite = "utility/reset",
        style = "train_schedule_action_button"
      }
      for _,inventory in pairs(core_dict.inventories.history) do
        local inventory_gui = gui.panes.control.frame.add{
          type = "inventory",
          slots_per_row = 5,
          handle_cursor_transfer = false,
          handle_cursor_split = false,
          handle_open_item = false,
          handle_open_mod_item = false,
          handle_send_stack_to_trash = false,
          handle_send_stacks_to_trash = false
        }
        inventory_gui.inventory=inventory
      end
    end
    
    gui.panes.inventories = {}
    gui.panes.inventories.frame = gui.pane_space.add{
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical"
    }
    gui.panes.inventories.label = gui.panes.inventories.frame.add{
      type = "label",
      caption = {"gui-element.bpio-inventories-label"},
      style = "frame_title"
    }
    gui.panes.inventories.blueprint_label = gui.panes.inventories.frame.add{
      type = "label",
      caption = {"gui-element.bpio-blueprint-label"}
    }
    gui.panes.inventories.blueprint_inventory = gui.panes.inventories.frame.add{
      type = "inventory",
      slots_per_row = 1
    }
    gui.panes.inventories.building_label = gui.panes.inventories.frame.add{
      type = "label",
      caption = {"gui-element.bpio-building-label"}
    }
    gui.panes.inventories.building_inventory = gui.panes.inventories.frame.add{
      type = "inventory",
      slots_per_row = 6,
      handle_send_stack_to_trash = false,
      handle_send_stacks_to_trash = false
    }
    gui.panes.inventories.input_label = gui.panes.inventories.frame.add{
      type = "label",
      caption = {"gui-element.bpio-input-label"}
    }
    gui.panes.inventories.input_inventory =  gui.panes.inventories.frame.add{
      type = "inventory",
      slots_per_row = 6
    }
    gui.panes.inventories.output_label = gui.panes.inventories.frame.add{
      type = "label",
      caption = {"gui-element.bpio-output-label"}
    }
    gui.panes.inventories.output_inventory = gui.panes.inventories.frame.add{
      type = "inventory",
      slots_per_row = 6
    }

    gui.panes.inventories.blueprint_inventory.inventory = core_dict.inventories.blueprint
    gui.panes.inventories.blueprint_inventory.style.maximal_width=48
    gui.panes.inventories.building_inventory.inventory = core_dict.inventories.building
    gui.panes.inventories.input_inventory.inventory = core_dict.inventories.input
    gui.panes.inventories.output_inventory.inventory = core_dict.inventories.output
  end
end



--====================
--===== Building =====
--====================

local function on_bpio_created(event)
  if event.effect_id ~= "bpio-built-event" then return end
  ---@type LuaEntity
  local site = event.target_entity
  local surface = site.surface
  local position = site.position
  local force = site.force

  local core
  local internal_inputs = {}
  local input
  local output
  if position.x and position.y then
    core = surface.create_entity{
      name="bpio-core",
      position={x=position.x,y=position.y},
      force=force
    }
    for i = 1,6 do
      local internal_input=surface.create_entity{
        name="bpio-internal-input",
        position={x=position.x,y=position.y},
        force=force
        }
      internal_inputs[i]=internal_input.get_inventory(defines.inventory.chest)
    end
    input = surface.create_entity{
      name="bpio-input",
      position={x=position.x-5,y=position.y},
      force=force
    }
    output = surface.create_entity{
      name="bpio-output",
      position={x=position.x+5,y=position.y},
      force=force
    }
  end
  local core_id
  local in_inventory
  local out_inventory
  if core and input and output then
    core_id = core.unit_number
    in_inventory  = input.get_inventory(defines.inventory.chest)
    out_inventory = output.get_inventory(defines.inventory.chest)
  else
    print("Something went wrong while building our entities. Remove everything and try again")
    return
  end

  storage.dictionary.core[core_id] = 
  {
    id=core_id,
    state="off",
    entities=
    {
      core   = core,
      input  = input,
      output = output
    },
    inventories=
    {
      blueprint = game.create_inventory(1),
      building  = game.create_inventory(30), 
      input     = in_inventory,
      output    = out_inventory,
      history   = internal_inputs 
    }
  }
  site.destroy()
end

script.on_event(defines.events.on_script_trigger_effect, on_bpio_created)



--=========================
--===== GUI Lifecycle =====
--=========================

script.on_event(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  if not 
  ( event.gui_type == defines.gui_type.entity and entity ~= nil and
    entity.name and entity.name == "bpio-core" ) 
  then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local id = entity.unit_number
  local dicts = storage.dictionary
  if not dicts then return end

  draw_gui(player, dicts.core[id])
  dicts.player[player.index]=id
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if not (event.element and event.element.name == "bpio-menu") then return end  
  
  local player = game.get_player(event.player_index)
  if not player then return end
  
  event.element.destroy()
  storage.dictionary.player[player.index]=nil
end)

script.on_event(defines.events.on_player_controller_changed, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local dicts = storage.dictionary
  if not dicts then return end
  if dicts.player[player.index] == nil then return end

  local id = dicts.player[player.index]
  draw_gui(player, dicts.core[id])
end)



--=======================
--===== GUI Actions =====
--=======================

script.on_event(defines.events.on_gui_click, function(event)
  if event.element.name ~= "bpio-simulate" then return end

  local player = game.get_player(event.player_index)
  if not player then return end
  local force = player.force --[[@as LuaForce]]
  if not (force and force.print) then return end

  local dicts = storage.dictionary --[[@as dictionaryDict]]
  if not (dicts and dicts.surface.status == nil) then
    force.print("Another blueprint core is processing. Wait until it finishes.")
    return
  end

  local id = dicts.player[player.index]

  local core = dicts.core[id]
  if not is_valid_core(core,"both") then
    force.print("Invalid core")
    return
  end

  local bp_slot = core.inventories.blueprint[1]
  if not (bp_slot and bp_slot.valid and bp_slot.valid_for_read and bp_slot.is_blueprint and bp_slot.is_blueprint_setup()) then
    force.print("Invalid blueprint slot")
    return
  end

  local size = bp_slot.blueprint_snap_to_grid 
  if size == nil or size.x == nil or size.y == nil then
    force.print("Blueprint needs to have relative snapping enabled")
    return
  end

  if bp_slot.blueprint_absolute_snapping then
    force.print("Blueprint has absolute snapping. Needs to be relative")
    return
  end

  local building_inventory = core.inventories.building
  local building_wants = bp_slot.cost_to_build
  local building_has = building_inventory.get_contents()
  local building_error = false

  local wants_list = as_item_list(building_wants)
  local has_list = as_item_list(building_has)
  
  if not (wants_list["bpio-input-watcher"] and 
          wants_list["bpio-input-watcher"].normal == 1 and 
          wants_list["bpio-output-watcher"] and 
          wants_list["bpio-output-watcher"].normal == 1) then
    force.print("Your blueprint has to have a single input and a single output")
    return
  end

  if is_super_set(has_list,wants_list) then
    for _,item_format in pairs(building_wants) do
      local removed = building_inventory.remove(item_format)
      if removed ~= item_format.count then building_error = true end
    end
  else
    force.print("You don't have enough items to build this blueprint")
    return
  end

  if building_error then
    force.print("There was an error while building the core. Unsure what happened. Proceeding normally...")
  else
    force.print("Used items needed to build")
  end 

  core.cost = building_wants
  core.input = core.inventories.input.get_contents()
  core.input_list = as_item_list(core.input)
  core.check = 0
  core.history_lists = {}
  core.state = "booting"

  local surface = dicts.surface --[[@as surfaceDict]]
  surface.building_force=force
  surface.core=core
  surface.size=size
  surface.properties = {}

  local source_surface = core.entities.core.surface
  for _,property in pairs(prototypes.surface_property) do
    surface.properties[property] = source_surface.get_property(property)
  end


  surface.lua = game.create_surface("bpio-surface",{width=size.x,height=size.y})
  for property,value in pairs(surface.properties) do
    surface.lua.set_property(property,value)
  end
  surface.lua.generate_with_lab_tiles = true
  surface.lua.request_to_generate_chunks({0,0},math.max(math.ceil(size.x/32),math.ceil(size.y/32)))
  surface.lua.force_generate_chunk_requests()
  surface.force = game.create_force("bpio-force")
  surface.force.copy_from(force)
  surface.progress = 0
  surface.progress_bars = {}
  force.print("Created surface and force")

  storage.queue.surface[event.tick+1]="build_ghosts"

  for viewer,opened in pairs(dicts.player) do
    if opened == id then
      local lua_viewer = game.get_player(viewer)
      if lua_viewer then
        draw_gui(lua_viewer,surface.core)
      end 
    end
  end

end)



--====================
--===== Queueing =====
--====================

local function on_tick(event)
  local clock = event.tick

  ---@type queueDict
  local queues = storage.queue
  if queues == nil then return end
  local core_now = queues.core[clock]
  local surface_now = queues.surface[clock]
  if not core_now and not surface_now then return end

  ---@type dictionaryDict
  local dicts = storage.dictionary
  if not dicts then return end

  if surface_now then
    local surface = dicts.surface --[[@as surfaceDict]]
    if surface_now == "build_ghosts" then
      local blueprint = surface.core.inventories.blueprint[1]
      local ghosts = blueprint.build_blueprint{surface=surface.lua,force=surface.force, position={0,0}}
      if not next(ghosts) then 
        surface.building_force.print("Could not build ghosts. Recalling")
        surface_recall(surface)
      else
        surface.ghosts = ghosts
        queues.surface[clock+1] = "begin_entities"
        surface.building_force.print("Placed ghosts")
      end
    end
    if surface_now == "begin_entities"then
      for ghostid,ghost in pairs(surface.ghosts) do
        ghost.revive()
        surface.ghosts[ghostid]=nil
      end
      
      if next(surface.ghosts) then
        queues.surface[clock+1] = "retry_entities"
        surface.building_force.print("Not all entities were built. Retrying...")
      else
        queues.surface[clock+1] = "initialize_logs"
        surface.building_force.print("Built entities cleanly")
      end
    end
    if surface_now == "retry_entities" then
      for ghostid,ghost in pairs(surface.ghosts) do
        ghost.revive()
        surface.ghosts[ghostid]=nil
      end
      
      if next(surface.ghosts) then
        queues.surface[clock+1] = "retry_entities"
        surface.building_force.print("Not all entities were built. Retrying...")
      else
        queues.surface[clock+1] = "initialize_logs"
        surface.building_force.print("Built entities after some passes.")
      end
    end
    if surface_now == "initialize_logs" then
      local input_watcher = surface.lua.find_entities_filtered{name = "bpio-input-watcher"}
      local output_watcher = surface.lua.find_entities_filtered{name = "bpio-output-watcher"}
      if not (input_watcher[1] and output_watcher[1]) then goto abort2 end                                                                                                                                            
      surface.input_watcher = input_watcher[1].get_inventory(defines.inventory.chest)
      surface.output_watcher = output_watcher[1].get_inventory(defines.inventory.chest)
      if not (surface.input_watcher and surface.output_watcher) then goto abort2 end
      for _,item_format in pairs(surface.core.input) do
        surface.input_watcher.insert(item_format)
      end
      queues.surface[clock+1] = "busy"
      surface.building_force.print("Spawned items")
      surface.building_force.print("Began logging...")
      ::abort2::
    end
    if surface_now == "busy" then
      surface.progress = surface.progress + 1
      if surface.progress % 120 == 0 then
        surface.core.check = surface.core.check + 1
        local current_input = surface.input_watcher.get_contents()
        local current_list = as_item_list(current_input)
        surface.core.history_lists[surface.core.check] = items_consumed(surface.core.input_list,current_list) 
      end
      for _,progress_bar in pairs(surface.progress_bars) do
        if progress_bar.valid then progress_bar.value = surface.progress*5/3600 end 
      end
      if surface.core.check == 6 then
        surface.core.output = surface.output_watcher.get_contents()
        surface.core.state = "standby"
        queues.surface[clock+5] = "epilog"
      else
        queues.surface[clock+5] = "busy"
      end
    end
    if surface_now == "epilog" then
      local id = surface.core.id
      local core = dicts.core[id]
      surface_shutdown(surface)
      core.history={}
      local history_format = core.history
      for time,list in pairs(core.history_lists) do
        local time_inventory = core.inventories.history[time]
        local item_format = as_item_quality_count(list)
        history_format[time] = item_format
        for _,item_spec in pairs(item_format) do
          time_inventory.insert(item_spec)
        end
      end
      for viewer,opened in pairs(dicts.player) do
        if opened == id then
          local lua_viewer = game.get_player(viewer)
          if lua_viewer then
            draw_gui(lua_viewer,core)
          end 
        end
      end
    end
  end
end

script.on_event(defines.events.on_tick, on_tick)
