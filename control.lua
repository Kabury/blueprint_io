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

---@class coreDict
---@field entities coreEntities
---@field inventories coreInventories
---@field cost ItemWithQualityCount[] How much did it cost to activate this core.
---@field state "off"|"booting"|"on"
---@field check number Check number

---@class surfaceDict
---@field core coreDict The core associated to the surface
---@field status string? What stage the surface is on
---@field lua LuaSurface The lua pointer to the surface
---@field force LuaForce The lua pointer to the temporary force
---@field building_force LuaForce The building force
---@field properties table<LuaSurfacePropertyPrototype,double> The building surface's properties. Stored so our new surface can copy them later.
---@field size TilePosition Size of the blueprint
---@field ghosts LuaEntity[] The ghosts we build

---@alias playerID uint32

---@class dictionaryDict
---@field core table<coreID,coreDict>
---@field surface surfaceDict
---@field player table<playerID,coreID>

---@alias time number
---@alias coreID number

---@class queueDict
---@field core table<time, coreID[]>
---@field surface table<time, coreID>

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

---@param dict coreDict
---@param mode "entities"|"inventories"|"both"
local function is_valid_core(dict,mode)
  local entities_check = true
  if mode == "entities" or mode == "both" then
    for _,entity in pairs(dict.entities) do
      entities_check = entities_check and entity.valid
    end
  end

  local inventories_check = true
  if mode == "inventories" or mode == "both" then
    for _,inventory in pairs(dict.inventories) do
      inventories_check = inventories_check and inventory.valid
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

---@param dict surfaceDict
local function surface_destroy(dict)
  game.delete_surface("bpio-surface")
  game.merge_forces("bpio-force",dict.building_force)
  dict.building_force = nil
  dict.force = nil
  dict.core = nil
  dict.size = nil
  dict.properties = nil
  dict.status = nil
  dict.lua = nil
  storage.queue.surface = {}
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
  gui.master = player.gui.screen.add
  {
    type = "frame",
    name = "bpio-menu",
    caption = { "gui-element.gui-title" },
    style = "inset_frame_container_frame",
    direction = "vertical"
  }
  gui.pane_space = gui.master.add
  {
    type="flow",
    direction="horizontal"
  }
  gui.panes={}
  gui.master.auto_center = true
  player.opened = gui.master


  if core_dict.state == "booting" then
    gui.panes.booting = {} 
    gui.panes.booting.frame = gui.pane_space.add
    {
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical"
    }
    gui.panes.booting.label = gui.panes.booting.frame.add
    {
      type = "label",
      caption = {"gui-element.booting-label"},
      style = "frame_title"
    }
    gui.panes.booting.surface_label = gui.panes.booting.frame.add
    {
      type = "label",
      caption = {"gui-element.booting-surface-label",core_dict.entities.core.surface.name:gsub("^%l", string.upper)}
    }


    gui.panes.booting.preview_frame = gui.panes.booting.frame.add
    {
      type = "frame",
      style = "deep_frame_in_shallow_frame"
    }
    local bpio_surface = game.surfaces["bpio-surface"]

    if bpio_surface ~=nil then
      local bpio_size = storage.dictionary.surface.size
      local res = player.display_resolution 
      local resy = res.height - 300
      local resx = res.width - 300

      local tile_size = 32
      local zoom_x = (resx-50) / (bpio_size.x * tile_size)
      local zoom_y = (resy-50) / (bpio_size.y * tile_size)
      local target_zoom = math.min(zoom_x, zoom_y)

      gui.panes.booting.bpio_surface = gui.panes.booting.frame.add
      {
        type = "camera",
        position = {0,0},
        surface_index = bpio_surface.index,
        zoom = target_zoom
      }
      
      gui.panes.booting.bpio_surface.style.natural_height = resy
      gui.panes.booting.bpio_surface.style.natural_width = resx
    end


  else
    gui.panes.player={}
    gui.panes.player.frame = gui.pane_space.add
    {
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical"
    }
    gui.panes.player.flow = gui.panes.player.frame.add
    {
      type = "flow",
      style = "two_module_spacing_vertical_flow",
      direction = "vertical"
    }
    gui.panes.player.label = gui.panes.player.flow.add
    {
      type = "label",
      caption = {"gui-element.player-label"}
    }
    gui.panes.player.inventory = gui.panes.player.flow.add
    {
      type = "inventory",
      slots_per_row = prototypes.utility_constants.inventory_width
    }
    local player_inventory = player.get_main_inventory()
    gui.panes.player.inventory.inventory = player_inventory


    gui.panes.control = {} 
    gui.panes.control.frame = gui.pane_space.add
    {
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical"
    }
    gui.panes.control.label = gui.panes.control.frame.add
    {
      type = "label",
      caption = {"gui-element.mod-control-label"},
      style = "frame_title"
    }

    gui.panes.control.preview_frame = gui.panes.control.frame.add
    {
      type = "frame",
      style = "deep_frame_in_shallow_frame"
    }
    gui.panes.control.preview = gui.panes.control.preview_frame.add
    {
      type = "camera",
      position = core_dict.entities.core.position,
      surface_index =  core_dict.entities.core.surface_index,
      zoom = 0.65
    }
    gui.panes.control.preview.style.natural_height=200
    gui.panes.control.preview.style.natural_width=400

    gui.panes.control.surface_label = gui.panes.control.frame.add
    {
      type = "label",
      caption = {"gui-element.mod-control-surface-label",core_dict.entities.core.surface.name:gsub("^%l", string.upper)}
    }


    if core_dict.state == "off" then
      gui.panes.control.status_label = gui.panes.control.frame.add
      {
        type = "label",
        caption = {"gui-element.mod-control-status-off-label"}
      }
      gui.panes.control.button = gui.panes.control.frame.add
      {
        type = "sprite-button",
        name = "bpio-simulate",
        sprite = "utility/play",
        style = "train_schedule_action_button"
      }
    end

    gui.panes.inventories = {}
    gui.panes.inventories.frame = gui.pane_space.add
    {
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical"
    }
    gui.panes.inventories.label = gui.panes.inventories.frame.add
    {
      type = "label",
      caption = {"gui-element.inventories-label"},
      style = "frame_title"
    }
    gui.panes.inventories.blueprint_label = gui.panes.inventories.frame.add
    {
      type = "label",
      caption = {"gui-element.blueprint-label"}
    }
    gui.panes.inventories.blueprint_inventory = gui.panes.inventories.frame.add
    {
      type = "inventory",
      slots_per_row = 5
    }
    gui.panes.inventories.building_label = gui.panes.inventories.frame.add
    {
      type = "label",
      caption = {"gui-element.building-label"}
    }
    gui.panes.inventories.building_inventory = gui.panes.inventories.frame.add
    {
      type = "inventory",
      slots_per_row = 6
    }
    gui.panes.inventories.input_label = gui.panes.inventories.frame.add
    {
      type = "label",
      caption = {"gui-element.input-label"}
    }
    gui.panes.inventories.input_inventory =  gui.panes.inventories.frame.add
    {
      type = "inventory",
      slots_per_row = 6
    }
    gui.panes.inventories.output_label = gui.panes.inventories.frame.add
    {
      type = "label",
      caption = {"gui-element.output-label"}
    }
    gui.panes.inventories.output_inventory = gui.panes.inventories.frame.add
    {
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
  local core = event.target_entity
  local surface = core.surface
  local position = core.position
  local force = core.force

  local input
  local output
  if position.x and position.y then
    input = surface.create_entity
    {
      name="bpio-input",
      position={x=position.x-5,y=position.y},
      force=force
    }
    output = surface.create_entity
    {
      name="bpio-output",
      position={x=position.x+5,y=position.y},
      force=force
    }
  end
  local in_inventory
  local out_inventory
  if input and output then
    in_inventory  = input.get_inventory(defines.inventory.chest)
    out_inventory = output.get_inventory(defines.inventory.chest)
  end
  
  local id = core.unit_number

  storage.dictionary.core[id] = 
  {
    id=id,
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
      output    = out_inventory
    }
  }
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
  if size == nil then
    force.print("Blueprint needs to have relative snapping enabled")
    return
  end

  if bp_slot.blueprint_absolute_snapping then
    force.print("Blueprint has absolute snapping. Needs to be relative")
    return
  end

  local building_wants = bp_slot.cost_to_build
  local building_has = core.inventories.building.get_contents()
  local building_error = false

  if is_super_set(as_item_list(building_has),as_item_list(building_wants)) then
    for _,item_format in pairs(building_wants) do
      local removed = core.inventories.building.remove(item_format)
      if removed ~= item_format.count then building_error = true end
    end
  else
    force.print("You don't have enough items to build this blueprint")
    return
  end

  if building_error then
    force.print("There was an error while building the core. Unsure what happened. Proceeding normally...")
  else
    force.print("Got items needed to build")
  end

  core.cost = building_wants
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

  surface.status = "prepare_force"
  storage.queue.surface[event.tick+5]=id
  draw_gui(player, core)
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
    if surface.status == "prepare_force" then
      surface.force = game.create_force("bpio-force")
      surface.force.copy_from(surface.building_force)
      surface.status = "create_surface"
      queues.surface[clock+5] = surface_now
      surface.building_force.print("Created force")
    end
    if surface.status == "create_surface" then
      surface.lua = game.create_surface("bpio-surface",{width=surface.size.x,height=surface.size.y})
      for property,value in pairs(surface.properties) do
        surface.lua.set_property(property,value)
      end
      surface.lua.generate_with_lab_tiles = true
      surface.status = "queue_chunks"
      queues.surface[clock+5] = surface_now
      surface.building_force.print("Created surface")
    end
    if surface.status == "queue_chunks" then
      local size = surface.size --[[@as TilePosition.struct]]
      surface.lua.request_to_generate_chunks({0,0},math.max(math.ceil(size.x/32),math.ceil(size.y/32)))
      surface.status = "finish_chunks"
      queues.surface[clock+5] = surface_now
      surface.building_force.print("Queued chunks")
    end
    if surface.status == "finish_chunks" then
      surface.lua.force_generate_chunk_requests()
      surface.status = "build_ghosts"
      queues.surface[clock+5] = surface_now
      surface.building_force.print("Finished chunks")
    end
    if surface.status == "build_ghosts" then
      local id = surface.core.entities.core.unit_number
      for player,core in pairs(dicts.player) do
        if core == id then
          local lua_player = game.get_player(player)
          if lua_player then
            draw_gui(lua_player,surface.core)
          end 
        end
      end
      
      local blueprint = surface.core.inventories.blueprint[1]

      local ghosts = blueprint.build_blueprint{surface=surface.lua,force=surface.force, position={0,0}}
      if not next(ghosts) then 
        surface.building_force.print("Could not build ghosts. Aborting")
        surface_destroy(surface)
        goto abort
      end
      surface.ghosts = ghosts
      surface.status = "begin_entities"
      queues.surface[clock+5] = surface_now
      surface.building_force.print("placed ghosts")
      ::abort::
    end
    if surface.status == "begin_entities"then
      for ghostid,ghost in pairs(surface.ghosts) do
        ghost.revive()
        surface.ghosts[ghostid]=nil
      end
      queues.surface[clock+5] = surface_now
      if next(surface.ghosts) then
        surface.status = "retry_entities"
        surface.building_force.print("Not all entities were built. Retrying...")
      else
        surface.status = "begin_logging"
        surface.building_force.print("Built entities cleanly")
      end
    end
    if surface.status == "retry_entities" then
      for ghostid,ghost in pairs(surface.ghosts) do
        ghost.revive()
        surface.ghosts[ghostid]=nil
      end
      queues.surface[clock+5] = surface_now
      if next(surface.ghosts) then
        surface.building_force.print("Not all entities were built. Retrying...")
      else
        surface.status = "begin_logging"
        surface.building_force.print("Built entities after some passes.")
      end
    end
    if surface.status == "begin_logging" then
      surface.building_force.print("Began logging...")


    end
  end
end

script.on_event(defines.events.on_tick, on_tick)