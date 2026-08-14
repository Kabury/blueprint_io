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

---@alias checkStatus "?"|"y"|"n"

---@class coreDict
---@field id coreID
---@field entities coreEntities
---@field inventories coreInventories
---@field state "off"|"booting"|"standby"|"on"
---@field check number Check number
---@field checks checkStatus[] Status of each check
---@field properties table<LuaSurfacePropertyPrototype,double> The building surface's properties. Stored so our new surface can copy them later.
---@field statistics LuaFlowStatistics
---@field surface LuaSurface Where the core is. Saved reference for later.
---@field surface_index number The index.
---@field position MapPosition The place the core is in the surface.
---@field force LuaForce Who owns the core.
---@field pollution number The pollution we registered during the simulation
---@field cost ItemWithQualityCount[] What items we used to build this core. To give back to the player.
---@field input ItemWithQualityCount[] What will be spawned in the surface, once.
---@field output ItemWithQualityCount[] What will be spawned in the active entity every cycle.
---@field input_list itemList We use this to compare each point in time when the surface is being simulated.
---@field output_list itemList We use this for the GUI
---@field history itemList[] Lists of items at different times of the surface



---@class surfaceDict
---@field core coreDict The core associated to the surface
---@field status string? What stage the surface is on
---@field lua LuaSurface The lua pointer to the surface
---@field force LuaForce The lua pointer to the temporary force
---@field building_force LuaForce The building force
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
---@alias status "build_ghosts"|"begin_entities"|"retry_entities"|"initialize_inventories"|"initialize_logs"|"busy"|"epilog"

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
local BAR_FREQUENCY = 5

local kl = require("__klib__.runtime_stage")  
local flib = require("__flib__.gui")

local function saneFormatString(str)
    local result = str:gsub("-", " ")
    result = result:gsub("^%l", string.upper)
    return result
end

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

---@param gui_element LuaGuiElement
---@param item_list itemList
---@param time? number
---@param unit? "s"|"m"|"h"
local function draw_item_list(gui_element, item_list,time,unit)
  local flow = gui_element.add{
    type="flow",
    direction = "horizontal"
  }
  if time and unit then
    local time_flow =     flow.add{
      type = "flow",
      direction = "horizontal"
    }
    local button = time_flow.add{
      type = "sprite-button",
      sprite = "utility/clock",
      number = time
    }
    local new_text = time_flow.add{
      type = "label",
      caption = unit,
      font = "count-font"
    }
    new_text.style.font = "count-font"
    new_text.style.top_margin=20
    new_text.style.left_margin=-7
    time_flow.style.natural_width= 48
  end
  for item,qcount in pairs(item_list) do
    for quality,count in pairs(qcount) do
      flow.add{
        type = "sprite-button",
        sprite = "item/"..item,
        quality = quality,
        number = count
      }
    end
  end
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
    for _,inventory in pairs(dict.inventories) do
      inventories_check = inventories_check and inventory.valid   
    end
  end

  return entities_check and inventories_check
end

---@param dict coreDict
local function core_destroy(dict)
  if dict.inventories.blueprint.valid then dict.inventories.blueprint.destroy() end
  if dict.inventories.building.valid then dict.inventories.building.destroy() end
  if dict.entities.output.valid then dict.entities.output.die() end
  if dict.entities.input.valid then dict.entities.input.die() end
  if dict.entities.core.valid then dict.entities.core.die() end
end

local function nil_surface_data()
  local data = storage.dictionary.surface
  data.core = nil
  data.status = nil
  data.lua = nil
  data.force = nil
  data.building_force = nil
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
  local force = dict.force --[[@as LuaForce]]
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
  local force= core.force --[[@as LuaForce]]
  force.print("Refunded buildings")
  nil_surface_data()
end

--===== Functions for GUI

---@param core_dict coreDict
local function gui_kick_everyone(core_dict)
  for viewer,opened in pairs(storage.dictionary.player) do
    if opened == core_dict.id then
      local lua_viewer = game.get_player(viewer)
      if lua_viewer then
        if lua_viewer.gui.screen["bpio_menu"] then
          lua_viewer.gui.screen["bpio_menu"].destroy()
        end
      end 
    end
  end
end

---@param player LuaPlayer
---@param core_dict coreDict
local function draw_gui(player, core_dict)
  local valid = is_valid_core(core_dict, "both")
  if not valid then
    gui_kick_everyone(core_dict)
    core_destroy(core_dict) 
    return
  end

  if player.gui.screen["bpio_menu"] then
    player.gui.screen["bpio_menu"].destroy()
  end

  local gui = {}
  gui.master = flib.add(player.gui.screen, {
    type = "frame",
    name = "bpio_menu",
    caption = { "gui-element.bpio-gui-title" },
    style = "inset_frame_container_frame",
    direction = "vertical",
    elem_mods = { auto_center = true },
    children = {
      {
        type = "flow",
        name = "mflow",
        direction = "horizontal"
      }
    }
  }--[[@as flib.GuiElemDef]])
  player.opened = gui.master.bpio_menu

  if core_dict.state == "booting" then
    
    local surface = storage.dictionary.surface --[[@as surfaceDict]]
    local res = player.display_resolution 
    local target_zoom
    if surface.size.x and surface.size.y then 
      local zoom_x = (res.width - 350) / (surface.size.x * TILE_RESOLUTION)
      local zoom_y = (res.height - 350) / (surface.size.y * TILE_RESOLUTION)
      target_zoom = math.min(zoom_x, zoom_y)
    else
      target_zoom = 1
    end

    gui.booting = flib.add(gui.master.mflow, {
      type = "frame",
      style = "inside_shallow_frame_with_padding",
      direction = "vertical",
      {
        type = "flow",
        direction = "horizontal",
        {
          type = "sprite",
          sprite = "utility/status_blue",
          style_mods = { top_margin = 4 },
        },
        {
          type = "label",
          caption = {"gui-element.bpio-status-booting-label"},
          style = "frame_title"
        },
      },
      {
          type = "progressbar",
          name = "progress_bar",
          style_mods = { natural_width = math.floor((res.width - 300) ), bar_width = 12 }
      },
      {
        type = "frame",
        style = "deep_frame_in_shallow_frame",
        {
          type = "camera",
          position = {0, 0},
          surface_index = surface.lua.index,
          zoom = target_zoom,
          style_mods = { natural_width = res.width - 300, natural_height = res.height - 300 }
        }
      }
    })
    surface.progress_bars[player.index] = gui.booting.progress_bar

  else

    gui.frames = flib.add(gui.master.mflow, {
      type = "flow",
      direction = "horizontal",
      {
        type = "frame",
        name = "lframe",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical",
        {
          type = "flow",
          style = "two_module_spacing_vertical_flow",
          direction = "vertical",
          style_mods = { vertically_stretchable = true },
          {
            type = "label",
            caption = {"gui-element.bpio-player-label"}
          },
          {
            type = "inventory",
            name = "player_inventory",
            slots_per_row = prototypes.utility_constants.inventory_width,
            elem_mods = { inventory = player.get_main_inventory() }
          }
        }
      },
      {
        type = "frame",
        style = "inside_shallow_frame",
        name = "rframe",
        direction = "vertical",
        {
          type = "frame",
          name = "right_inset",
          style = "deep_frame_in_shallow_frame",
          direction = "vertical",
          {
            type = "tabbed-pane",
            name = "bpio_tabbed_pane",
            {
              type = "tab",
              name = "control_tab",
              caption = { "gui-element.bpio-control-label" },
              style_mods = { vertically_stretchable = true}
            },
            {
              type = "tab",
              name = "surface_tab",
              caption = { "gui-element.bpio-surface-label" },
              style_mods = { vertically_stretchable = true }
            },
            {
              type = "tab",
              name = "inventories_tab",
              caption = {"gui-element.bpio-inventories-label"},
              style_mods = { vertically_stretchable = true }
            },
            {
              type = "tab",
              name = "data_tab",
              caption = {"gui-element.bpio-data-label"},
              style_mods = { vertically_stretchable = true }
            }
          }
        }
      }
    })


    gui.control_container = flib.add(gui.frames.bpio_tabbed_pane,
    {
      type = "flow",
      direction = "vertical",
      name = "control_flow",
      style_mods = { padding = 12},
      {
        type = "flow",
        direction = "horizontal",
        {
          type = "sprite",
          style_mods = { top_margin = 2 },
          sprite =  core_dict.state == "off" and "utility/status_not_working" or 
                    core_dict.state == "standby" and "utility/status_yellow" or
                    core_dict.state == "on" and "utility/status_working"
        },
        {
          type = "label",
          caption = core_dict.state == "off" and {"gui-element.bpio-status-off-label"} or 
                    core_dict.state == "standby" and {"gui-element.bpio-status-standby-label"} or
                    core_dict.state == "on" and {"gui-element.bpio-status-on-label"}
        }
      },
      {
        type = "frame",
        style = "deep_frame_in_shallow_frame",
        {
          type = "camera",
          name = "preview",
          position = core_dict.position,
          surface_index = core_dict.surface_index,
          zoom = 0.65,
          style_mods = { natural_width = 350, natural_height = 150 }
        }
      },
      {
        type = "flow",
        direction = "horizontal",
        name = "checks_tray",
        visible = core_dict.state == "on",
      },
      {
        type = "flow",
        name = "button_tray",
        direction = "horizontal",
        {
          type = "sprite-button",
          name = "bpio-start-boot",
          sprite = "utility/play",
          style = "train_schedule_action_button",
          visible = core_dict.state == "off",
        },
        {
          type = "sprite-button",
          name = "bpio-turn-on",
          sprite = "utility/play",
          style = "train_schedule_action_button",
          visible = core_dict.state == "standby",
        },
        {
          type = "sprite-button",
          name = "bpio-turn-off",
          sprite = "utility/reset",
          style = "train_schedule_action_button",
          visible = core_dict.state == "standby",
        },
        {
          type = "sprite-button",
          name = "bpio-to-standby",
          sprite = "utility/pause",
          style = "train_schedule_action_button",
          visible = core_dict.state == "on",
        }
      }
    }--[[@as flib.GuiElemDef]])
    if core_dict.state == "on" then
      for _,status in pairs(core_dict.checks) do
        flib.add(gui.control_container.checks_tray,
        {
          type = "sprite",
          sprite =  status == "?" and "virtual-signal/signal-clock" or 
                    status == "y" and "virtual-signal/signal-check" or
                    status == "n" and "virtual-signal/signal-deny"
        }--[[@as flib.GuiElemDef]])
      end
    end
    flib.add(gui.control_container.control_flow,{ type = "empty-widget", style = "entity_frame_filler" }--[[@as flib.GuiElemDef]])
    gui.frames.bpio_tabbed_pane.add_tab(gui.frames.control_tab, gui.control_container.control_flow)


    gui.surface_container = flib.add(gui.frames.bpio_tabbed_pane,
    {
      type = "flow",
      direction = "vertical",
      name = "surface_flow",
      style_mods = { padding = 12},
      {
        type = "label",
        name = "surflabel",
        caption = {"gui-element.bpio-surface-show-label", saneFormatString(core_dict.surface.name)}
      },
    }--[[@as flib.GuiElemDef]])
    if core_dict.state ~= "off" then
      for property,value in pairs(core_dict.properties) do
        flib.add(gui.surface_container.surface_flow,
        {
          type = "label",
          caption = {"", property.localised_name, ": ", {property.localised_unit_key, property.is_time and value/60 or value} }
        }--[[@as flib.GuiElemDef]])
      end
    end
    flib.add(gui.surface_container.surface_flow,{ type = "empty-widget", style = "entity_frame_filler" }--[[@as flib.GuiElemDef]])
    gui.frames.bpio_tabbed_pane.add_tab(gui.frames.surface_tab, gui.surface_container.surface_flow)


    gui.inventories_container = flib.add(gui.frames.bpio_tabbed_pane, 
    {
      type = "flow",
      direction = "vertical",
      name = "inventories_flow",
      style_mods = { padding = 12},
      {
        type = "label",
        caption = {"gui-element.bpio-blueprint-label"}
      },
      {
        type = "inventory",
        name = "blueprint_inventory",
        slots_per_row = 1,
        style_mods = { maximal_width = 48 }, 
        elem_mods = { inventory = core_dict.inventories.blueprint }
      },
      {
        type = "label",
        caption = {"gui-element.bpio-building-label"}
      },
      {
        type = "inventory",
        name = "building_inventory",
        slots_per_row = 6,
        style_mods = { maximal_width = 40*6 }, 
        elem_mods = { inventory = core_dict.inventories.building }
      },
      {
        type = "label",
        caption = {"gui-element.bpio-input-label"}
      },
      {
        type = "inventory",
        name = "input_inventory",
        slots_per_row = 6,
        style_mods = { maximal_width = 40*6 }, 
        elem_mods = { inventory = core_dict.inventories.input }
      },
      {
        type = "label",
        caption = {"gui-element.bpio-output-label"}
      },
      {
        type = "inventory",
        name = "output_inventory",
        slots_per_row = 6,
        style_mods = { maximal_width = 40*6 }, 
        elem_mods = { inventory = core_dict.inventories.output }
      },
      { type = "empty-widget", style = "entity_frame_filler" }
    }--[[@as flib.GuiElemDef]])
    gui.frames.bpio_tabbed_pane.add_tab(gui.frames.inventories_tab, gui.inventories_container.inventories_flow)

    if core_dict.state ~= "off" then
      gui.data_container = flib.add(gui.frames.bpio_tabbed_pane, {
        type = "flow",
        direction = "vertical",
        name = "data_flow",
        style_mods = { natural_height = 400, vertically_stretchable = true, padding = 12 },
        {
          type = "flow",
          name = "inputs_flow",
          direction = "vertical"
        },
        { type = "flow", style_mods = {natural_height=10} },
        {
          type = "flow", direction = "horizontal",
          {
            type = "flow", style_mods = {natural_width=48}
          },
          {
            type = "sprite-button",
            name = "crafting_arrow",
            sprite = "utility/recipe_potential_arrow"
          },
        },
        { type = "flow", style_mods = {natural_height=10} },
        {
          type = "flow",
          name = "outputs_flow",
          direction = "vertical"
        },
        { type = "empty-widget", style = "entity_frame_filler" }
      }--[[@as flib.GuiElemDef]])
      gui.frames.bpio_tabbed_pane.add_tab(gui.frames.data_tab, gui.data_container.data_flow)

      local i = 1
      local times = {{0.5, "m"}, {1, "m"}, {1.5, "m"}, {2, "m"}}
      for _, item_list in pairs(core_dict.history) do
        if times[i] then
          draw_item_list(gui.data_container.inputs_flow, item_list, times[i][1], times[i][2])
        end
        i = i + 1
      end
      draw_item_list(gui.data_container.outputs_flow, core_dict.output_list, 2, "m")
    end
  end
end

---@param core_dict coreDict
local function redraw_everyone(core_dict)
  for viewer,opened in pairs(storage.dictionary.player) do
    if opened == core_dict.id then
      local lua_viewer = game.get_player(viewer)
      if lua_viewer then
        draw_gui(lua_viewer,core_dict)
      end 
    end
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
  local input
  local output
  if position.x and position.y then
    core = surface.create_entity{
      name="bpio-core",
      position={x=position.x,y=position.y},
      force=force
    }
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

  ---@type coreDict
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
      building  = game.create_inventory(48), 
      input     = in_inventory,
      output    = out_inventory
    },
    surface = surface,
    surface_index = surface.index,
    position = core.position,
    force = force,
    statistics = force.get_item_production_statistics(surface)
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
  if not (event.element and event.element.name == "bpio_menu") then return end  
  
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
  local start_boot = event.element.name == "bpio-start-boot"
  local turn_off = event.element.name == "bpio-turn-off"
  local turn_on = event.element.name == "bpio-turn-on"
  local to_standby = event.element.name == "bpio-to-standby"
  if not (start_boot or turn_off or turn_on or to_standby) then return end

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

  if start_boot then
    local bp_slot = core.inventories.blueprint[1]
    if not (bp_slot and bp_slot.valid and bp_slot.valid_for_read and bp_slot.is_blueprint and bp_slot.is_blueprint_setup()) then
      force.print("Invalid blueprint slot")
      return
    end

    local target_size = bp_slot.blueprint_snap_to_grid 
    if target_size == nil or target_size.x == nil or target_size.y == nil then
      force.print("Blueprint needs to have relative snapping enabled")
      return
    end

    local source_surface = core.surface
    local mgs = source_surface.map_gen_settings
    local source_size = {x=mgs.width,y=mgs.height}

    if target_size.x > source_size.x or target_size.y > source_size.y then
      force.print("The surface doesn't support a blueprint this wide/tall. Make it fit")
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
    core.history = {}
    core.state = "booting"
    core.properties = {}
    
    for _,property in pairs(prototypes.surface_property) do
      core.properties[property] = source_surface.get_property(property)
    end

    local surface = dicts.surface --[[@as surfaceDict]]
    surface.building_force=force
    surface.core=core
    surface.size=target_size
    surface.lua = game.create_surface("bpio-surface",{width=target_size.x,height=target_size.y})
    for property,value in pairs(core.properties) do
      surface.lua.set_property(property,value)
    end
    surface.lua.generate_with_lab_tiles = true
    surface.lua.request_to_generate_chunks({0,0},math.max(math.ceil(target_size.x/32),math.ceil(target_size.y/32)))
    surface.lua.force_generate_chunk_requests()
    surface.force = game.create_force("bpio-force")
    surface.force.copy_from(force)
    surface.progress = 0
    surface.progress_bars = {}
    force.print("Created surface and force")

    storage.queue.surface[event.tick+1]="build_ghosts"

    redraw_everyone(core)

  elseif turn_off then
    
    core.cost = nil
    core.input = nil
    core.input_list = nil
    core.output = nil
    core.output_list = nil
    core.check = nil
    core.checks = nil
    core.history = nil
    core.state = "off"

    redraw_everyone(core)
  
  elseif turn_on then
    core.checks = {"?","?","?","?"}
    core.check = 0
    core.state = "on"
    local time_slice = kl.get_or_set(storage.queue.core,event.tick+1)
    time_slice[#time_slice+1] = core.id

    redraw_everyone(core)

  elseif to_standby then
    core.checks = nil
    core.check = 0
    core.state = "standby"

    redraw_everyone(core)

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
      ::retry::
      local at_least_one = false
      for ghostid,ghost in pairs(surface.ghosts) do
        local _, revenant, proxies = ghost.revive()

        at_least_one = at_least_one or (revenant and revenant.valid)

        if revenant and revenant.valid then
          if proxies and proxies.item_requests then
            for _, item_format in pairs(proxies.item_requests) do
              revenant.insert(item_format)
            end
            proxies.destroy()
          end
          surface.ghosts[ghostid]=nil
        end
      end
      
      if next(surface.ghosts) then
        if at_least_one then 
          goto retry 
        else
          surface.building_force.print("The blueprint has something unbuildable. Aboring")
        end
      else
        queues.surface[clock+1] = "initialize_logs"
        surface.building_force.print("Built entities cleanly")
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
      if surface.progress % ((30*60) / BAR_FREQUENCY) == 0 then
        surface.core.check = surface.core.check + 1
        local current_input = surface.input_watcher.get_contents()
        local current_list = as_item_list(current_input)
        surface.core.history[surface.core.check] = items_consumed(surface.core.input_list,current_list) 
      end
      for _,progress_bar in pairs(surface.progress_bars) do
        if progress_bar.valid then progress_bar.value = surface.progress * BAR_FREQUENCY/(2*60*60) end 
      end
      if surface.core.check == ((2*60)/30) then
        local output = surface.output_watcher.get_contents()
        surface.core.output = output
        surface.core.output_list = as_item_list(output)
        surface.core.state = "standby"
        queues.surface[clock+5] = "epilog"
      else
        queues.surface[clock+5] = "busy"
      end
    end
    if surface_now == "epilog" then
      local id = surface.core.id
      local core = dicts.core[id]
      core.input = as_item_quality_count(core.history[4])
      core.pollution = surface.lua.get_total_pollution()
      surface_shutdown(surface)
      
      redraw_everyone(core)
    
    end
  end

  if core_now then
    for _,coreid in pairs(core_now) do
      ---@type coreDict
      local core = dicts.core[coreid]
      if core.state == "on" then
        if not is_valid_core(core,"both") then 
          redraw_everyone(core)
          core_destroy(core) 
          goto next_core 
        end

        if core.check == 0 then core.checks={"?","?","?","?"} end
        core.check = core.check+1

        local current_items = as_item_list(core.inventories.input.get_contents())
        if is_super_set(current_items,core.history[core.check]) then
          core.checks[core.check] = "y" 
        else
          core.checks[core.check] = "n"
          core.entities.core.damage(30,"neutral",nil,nil,core.entities.core)
          if not is_valid_core(core,"both") then 
            redraw_everyone(core)
            core_destroy(core) 
            goto next_core 
          end
        end

        if core.check == 4 then
          for _,item_format in pairs(core.input) do
            local actual_amount = core.inventories.input.remove(item_format)
            core.statistics.on_flow(item_format,-actual_amount)
          end
          if (core.checks[1]=="y" and core.checks[2]=="y" and core.checks[3]=="y" and core.checks[4]=="y") then
            for _,item_format in pairs(core.output) do
              local actual_amount = core.inventories.output.insert(item_format)
              core.statistics.on_flow(item_format,actual_amount)
            end
          end
          core.surface.pollute(core.position,core.pollution,core.entities.core)
          core.check = 0
        end
        
        local future_slice = kl.get_or_set(queues.core,clock+30*60)
        future_slice[#future_slice+1] = coreid
      end

      redraw_everyone(core)
    end
    ::next_core::
  end
end

script.on_event(defines.events.on_tick, on_tick)
