--===================
--===== Library =====
--===================

--===== Types

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
---@field state "off"|"booting"|"on"
---@field next number? When are we rechecking this core
---@field check number? Check number
---@field status boolean? Whether all checks have been successful so far



--===== Functions for cores

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



--===== Functions for GUI

local function draw_gui(player,core_dict)
  local valid = is_valid_core(core_dict,"both")
  if not valid then 
    core_destroy(core_dict) 
    return
  end

  if player.gui.screen.bpio_menu then
    player.gui.screen.bpio_menu.destroy()
  end

  local gui = {}
  gui.master = player.gui.screen.add
  {
    type = "frame",
    name = "bpio_menu",
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



  gui.panes.player={}
  gui.panes.player.frame = gui.pane_space.add
  {
    type = "frame",
    name = "player_frame",
    style = "inside_shallow_frame_with_padding",
    direction = "vertical"
  }
  gui.panes.player.flow = gui.panes.player.frame.add
  {
    type = "flow",
    direction = "vertical",
    style = "two_module_spacing_vertical_flow"
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
    name = "bpio-control",
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
  gui.panes.control.preview.entity = core_dict.entities.core

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
    name = "mod_inventory_frame",
    style = "inside_shallow_frame_with_padding",
    direction = "vertical"
  }
  gui.panes.inventories.label = gui.panes.inventories.frame.add
  {
    type = "label",
    caption = {"gui-element.mod-inventories-label"},
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


local kl = require("__klib__.runtime_stage")

--==========================
--===== Initialization =====
--==========================

local function init_storage()
  storage.coreDictionaries = {}
  storage.coreQueue = {}

  storage.surfaceDictionary = {}
  storage.surfaceQueue = {}
  storage.surfaceStatus = nil

  storage.player_gui_opened = {}
end

script.on_init(function()
  init_storage()
end)

local function reorganize(event)
  if event.setting == "bpio-stagger" then 
  end
end

script.on_event(defines.events.on_runtime_mod_setting_changed, reorganize)

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

  storage.coreDictionaries[id] = 
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
  local valid = event.gui_type == defines.gui_type.entity and
                event.entity and event.entity.name and event.entity.name == "bpio-core"
  if not valid then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local eid = event.entity.unit_number
  draw_gui(player, storage.coreDictionaries[eid])
  storage.player_gui_opened[player.index]=eid
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if not (event.element and event.element.name == "bpio-menu") then return end  
  
  local player = game.get_player(event.player_index)
  if not player then return end
  
  event.element.destroy()
  storage.player_gui_opened[player.index]=nil
end)

script.on_event(defines.events.on_player_controller_changed, function(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  if storage.player_gui_opened[player.index] == nil then return end

  local eid = storage.player_gui_opened[player.index]
  draw_gui(player, storage.coreDictionaries[eid])
end)



--=======================
--===== GUI Actions =====
--=======================

script.on_event(defines.events.on_gui_click, function(event)
  if event.element.name ~= "bpio-simulate" then return end
  local player = game.get_player(event.player_index)
  if player == nil then
    return
  end
  local force = player.force

  local coreDictionary = storage.coreDictionaries[storage.player_gui_opened[player.index]]
  if not is_valid_core(coreDictionary,"both") then
    force.print("Invalid Core")
    return
  end

  local bp_slot = coreDictionary.inventories.blueprint[1]
  if not (bp_slot and bp_slot.valid and bp_slot.valid_for_read and bp_slot.is_blueprint and bp_slot.is_blueprint_setup()) then
    force.print("Invalid Blueprint Slot")
    return
  end

  local dimensions = bp_slot.blueprint_snap_to_grid
  if dimensions == nil then
    force.print("Check snap to grid - absolute - in blueprint")
    return
  end

  if storage.surfaceQueue ~= nil then
    force.print("Another core is processing. Wait until it finishes.")
    return
  end

  local surface_occupants = storage.scratchpad.find_entities_filtered{limit=1}
  
  if #surface_occupants > 0 then
    force.print("There's entities still inside the core. This is a serious bug.")
    return
  end
  
  local ghosts = bp_slot.build_blueprint{surface="bpio-scratchpad",force="bpio",position={0,0},build_mode=defines.build_mode.superforced}

  if not ghosts or #ghosts == 0 then
    force.print("Blueprint failed to generate ghosts.")
    return
  end

  local clock = event.tick
  local surfaceQueue = {}
  local end_time = clock+10+600*6
  local time = clock+10
  while time < end_time do
    time = time+1
    surfaceQueue[time] = "log"
  end

  surfaceQueue[clock+6]="ghost_builds"
  surfaceQueue[clock+8]="end_ghost_builds"
  surfaceQueue[clock+10]="begin_log"
  surfaceQueue[clock+10+600*1]="summarize"
  surfaceQueue[clock+10+600*2]="summarize"
  surfaceQueue[clock+10+600*3]="summarize"
  surfaceQueue[clock+10+600*4]="summarize"
  surfaceQueue[clock+10+600*5]="summarize"
  surfaceQueue[clock+10+600*6]="summarize"
  surfaceQueue[clock+10+600*6+2]="end_log"
  surfaceQueue[clock+10+600*6+4]="cleanup"
  surfaceQueue[clock+10+600*6+6]="generate"
  surfaceQueue[clock+10+600*6+8]="force_generate"

  storage.surfaceQueue = surfaceQueue
  storage.ghosts = ghosts
end)



--==================
--===== Queues =====
--==================

local function on_tick(event)
  local clock = event.tick

  if storage.surfaceQueue == nil then
    return
  end

  local surfacePending = storage.surfaceQueue[clock]
  if surfacePending == nil then
    return
  end

  if surfacePending == "ghost_builds" and storage.ghosts then
    for ghostid,ghost in pairs(storage.ghosts) do
      ghost.revive()
      storage.ghosts[ghostid]=nil
      game.print("Ended build")
    end
  end

  if surfacePending == "end_ghost_builds" and storage.ghosts then
    for ghostid,ghost in pairs(storage.ghosts) do
      ghost.revive()
      storage.ghosts[ghostid]=nil
      game.print("Re-ended build")
    end
  end

  if surfacePending == "cleanup" then
    storage.scratchpad.clear()
  end

  if surfacePending == "generate" then
    storage.scratchpad.request_to_generate_chunks({0,0},40)
  end
  
  if surfacePending == "force_generate" then
    storage.scratchpad.force_generate_chunk_requests()
    storage.surfaceQueue=nil
  end

end

script.on_event(defines.events.on_tick, on_tick)