TILE_RESOLUTION = 32



---@param player LuaPlayer
---@param core coreDict
function booting_screen(gui,player,core)
  local raw = player.display_resolution
  local adj = player.display_scale * player.display_density_scale
  local resolution = {width=raw.width/adj, height=raw.height/adj}
  local target_zoom
  if core.sim.size and core.sim.size.x and core.sim.size.y then 
    local zoom_x = (resolution.width - 450) / (core.sim.size.x * TILE_RESOLUTION)
    local zoom_y = (resolution.height - 450) / (core.sim.size.y * TILE_RESOLUTION)
    target_zoom = math.min(zoom_x, zoom_y)
  else
    target_zoom = 1
  end
  if not core.sim.surface then return end

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
      }
    },
    {
      type = "flow",
      direction = "horizontal",
      style_mods = { bottom_padding = 8 }, --[[@diagnostic disable-line: missing-fields]]
      {
        type = "sprite-button",
        name = "bpio-force-off",
        sprite = "utility/stop",
        style = "train_schedule_action_button"
      },
      {
        type = "progressbar",
        name = "progress_bar",
        style_mods = { natural_width = math.floor((resolution.width - 400) - 32), bar_width = 12, top_margin = 7 } --[[@diagnostic disable-line: missing-fields]]
      }
    },
    {
      type = "frame",
      style = "deep_frame_in_shallow_frame",
      {
        type = "camera",
        position = {0, 0},
        surface_index = core.sim.surface.index,
        zoom = target_zoom,
        style_mods = { natural_width = resolution.width - 400, natural_height = resolution.height - 400 }
      }
    }
  })
  core.aux.progress_bars[player.index] = gui.booting.progress_bar
end



---@param player LuaPlayer
function create_tab_container(gui,player)
  gui.frames = flib.add(gui.master.mflow, 
  {
    type = "flow",
    direction = "horizontal",
    name = "divisor",
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
          name = "bpio_player_inventory",
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
            name = "inventories_tab",
            caption = {"gui-element.bpio-inventories-label"},
            style_mods = { vertically_stretchable = true }
          },
          {
            type = "tab",
            name = "surface_tab",
            caption = { "gui-element.bpio-surface-label" },
            style_mods = { vertically_stretchable = true }
          },
          {
            type = "tab",
            name = "data_tab",
            caption = {"gui-element.bpio-data-label"},
            style_mods = { vertically_stretchable = true }
          },
          {
            type = "tab",
            name = "circuit_tab",
            caption = {"gui-element.bpio-circuit-label"},
            style_mods = { vertically_stretchable = true }
          },
        }
      }
    }
  })
end



---@param core coreDict
function create_control_tab(gui,core)
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
        sprite =  core.state.status == "off" and "utility/status_not_working" or 
                  core.state.status == "standby" and "utility/status_yellow" or
                  core.state.status == "on" and "utility/status_working"
      },
      {
        type = "label",
        caption = core.state.status == "off" and {"gui-element.bpio-status-off-label"} or 
                  core.state.status == "standby" and {"gui-element.bpio-status-standby-label"} or
                  core.state.status == "on" and {"gui-element.bpio-status-on-label"}
      }
    },
    {
      type = "frame",
      style = "deep_frame_in_shallow_frame",
      {
        type = "camera",
        name = "preview",
        position = core.aux.position,
        surface_index = core.aux.surface_index,
        zoom = 0.9,
        style_mods = { natural_width = 400, natural_height = 400 }
      }
    },
    {
      type="flow",
      direction="horizontal",
      {
        type = "sprite-button",
        name = "bpio-blueprint-glance",
        sprite = "utility/side_menu_blueprint_library_icon",
        style = "train_schedule_action_button",
        style_mods = {padding = -8}
      },
      {
        type = "drop-down",
        name = "bpio_sprite",
        items =
        {
          {"gui-element.bpio-sprite-one-label"},
          {"gui-element.bpio-sprite-two-label"},
          {"gui-element.bpio-sprite-three-label"}
        }
      }
    },
    {
      type = "label",
      caption = {"gui-element.bpio-collider-orientation"},
      visible = core.state.status == "off"
    },
    {
      type = "flow",
      direction = "vertical",
      {
        type = "flow",
        direction = "horizontal",
        {
          type = "sprite-button",
          name = "bpio-direction-left-top",
          sprite = "virtual-signal/up-left-arrow",
          style = "train_schedule_action_button",
          visible = core.state.status == "off",
          toggled = core.aux.projector_direction == "left-top"
        },
        {
          type = "sprite-button",
          name = "bpio-direction-right-top",
          sprite = "virtual-signal/up-right-arrow",
          style = "train_schedule_action_button",
          visible = core.state.status == "off",
          toggled = core.aux.projector_direction == "right-top"
        }
      },
      {
        type = "flow",
        direction = "horizontal",
        {
          type = "sprite-button",
          name = "bpio-direction-left-bottom",
          sprite = "virtual-signal/down-left-arrow",
          style = "train_schedule_action_button",
          visible = core.state.status == "off",
          toggled = core.aux.projector_direction == "left-bottom"
        },
        {
          type = "sprite-button",
          name = "bpio-direction-right-bottom",
          sprite = "virtual-signal/down-right-arrow",
          style = "train_schedule_action_button",
          visible = core.state.status == "off",
          toggled = core.aux.projector_direction == "right-bottom"
        }
      }
    },
    {
      type="flow",
      direction="vertical",
      {
        type = "label",
        caption = {"gui-element.bpio-check-amount"},
        visible = core.state.status == "off"
      },
      {
        type="flow",
        direction="horizontal",
        {
          type = "slider",
          name = "bpio-check-amount-slider",
          minimum_value = 1,
          maximum_value = 10,
          elem_mods = { slider_value = core.state.check_info.amount },
          visible = core.state.status == "off",
          style_mods = { natural_width = 340}
        },
        {
          type = "textfield",
          name = "bpio-check-amount-box",
          elem_mods = { numeric = true, allow_decimal = false, allow_negative = false},
          text = tostring(math.floor(core.state.check_info.amount)),
          visible = core.state.status == "off",
          style_mods = { maximal_width = 60}
        }
      },
      {
        type = "label",
        caption = {"gui-element.bpio-check-time"},
        visible = core.state.status == "off"
      },
      {
        type="flow",
        direction="horizontal",
        {
          type = "slider",
          name = "bpio-check-time-slider",
          minimum_value = 10,
          maximum_value = 300,
          elem_mods = { slider_value = core.state.check_info.time },
          visible = core.state.status == "off",
          style_mods = { natural_width = 340}
        },
        {
          type = "textfield",
          name = "bpio-check-time-box",
          elem_mods = { numeric = true, allow_decimal = false, allow_negative = false},
          text = tostring(math.floor(core.state.check_info.time)),
          visible = core.state.status == "off",
          style_mods = { maximal_width = 60}
        }
      },
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
        visible = core.state.status == "off",
      },
      {
        type = "sprite-button",
        name = "bpio-turn-on",
        sprite = "utility/play",
        style = "train_schedule_action_button",
        visible = core.state.status == "standby",
      },
      {
        type = "sprite-button",
        name = "bpio-turn-off",
        sprite = "utility/reset",
        style = "train_schedule_action_button",
        visible = core.state.status == "standby",
      },
      {
        type = "sprite-button",
        name = "bpio-to-standby",
        sprite = "utility/pause",
        style = "train_schedule_action_button",
        visible = core.state.status == "on",
      },
      {
        type = "flow",
        direction = "horizontal",
        name = "checks_tray",
        visible = core.state.status == "on",
      }
    }
  }--[[@as flib.GuiElemDef]])
  if core.state.status == "on" then
    for _,status in pairs(core.state.checks) do
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
end



---@param core coreDict
function create_surface_tab(gui,core)
gui.surface_container = flib.add(gui.frames.bpio_tabbed_pane,
  {
    type = "flow",
    direction = "vertical",
    name = "surface_flow",
    style_mods = { padding = 12},
    {
      type = "label",
      name = "surflabel",
      caption = {"gui-element.bpio-surface-show-label", formatString(core.aux.surface.name)}
    },
  }--[[@as flib.GuiElemDef]])
  if core.state.status ~= "off" then
    for property,value in pairs(core.aux.properties) do
      flib.add(gui.surface_container.surface_flow,
      {
        type = "label",
        caption = {"", property.localised_name, ": ", {property.localised_unit_key, property.is_time and value/60 or value} }
      }--[[@as flib.GuiElemDef]])
    end
  end
  flib.add(gui.surface_container.surface_flow,{ type = "empty-widget", style = "entity_frame_filler" }--[[@as flib.GuiElemDef]])
  gui.frames.bpio_tabbed_pane.add_tab(gui.frames.surface_tab, gui.surface_container.surface_flow)
end



---@param core coreDict
function create_inventories_tab(gui,core)
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
      name = "bpio_blueprint_inventory",
      slots_per_row = 1,
      style_mods = { maximal_width = 48 }, --[[@diagnostic disable-line: missing-fields]] 
      elem_mods = { inventory = core.inv.blueprint } --[[@diagnostic disable-line: missing-fields]]
    },
    {
      type = "label",
      caption = {"gui-element.bpio-building-label"}
    },
    {
      type = "inventory",
      name = "bpio_building_inventory",
      slots_per_row = 7,
      style_mods = { maximal_width = 40*7 }, --[[@diagnostic disable-line: missing-fields]]
      elem_mods = { inventory = core.inv.building } --[[@diagnostic disable-line: missing-fields]]
    },
    {
      type = "label",
      caption = {"gui-element.bpio-input-label"}
    },
    {
      type = "inventory",
      name = "bpio_input_inventory",
      slots_per_row = 7,
      style_mods = { maximal_width = 40*7 }, --[[@diagnostic disable-line: missing-fields]]
      elem_mods = { inventory = core.inv.input } --[[@diagnostic disable-line: missing-fields]]
    },
    {
      type = "label",
      caption = {"gui-element.bpio-output-label"}
    },
    {
      type = "inventory",
      name = "bpio_output_inventory",
      slots_per_row = 7,
      style_mods = { maximal_width = 40*7 }, --[[@diagnostic disable-line: missing-fields]]
      elem_mods = { inventory = core.inv.output } --[[@diagnostic disable-line: missing-fields]]
    },
    { type = "empty-widget", style = "entity_frame_filler" }
  }--[[@as flib.GuiElemDef]])
  gui.frames.bpio_tabbed_pane.add_tab(gui.frames.inventories_tab, gui.inventories_container.inventories_flow)
end



---@param core coreDict
function create_data_tab(gui,core)
  gui.data_container = flib.add(gui.frames.bpio_tabbed_pane, 
  {
    type = "flow",
    direction = "vertical",
    name = "data_flow",
    style_mods = { natural_height = 400, vertically_stretchable = true, padding = 12 },
    {
      type = "flow",
      name = "inputs_flow",
      direction = "vertical"
    },
    { type = "flow", style_mods = {natural_height=10} }, --[[@diagnostic disable-line: missing-fields]]
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
    { type = "flow", style_mods = {natural_height=10} }, --[[@diagnostic disable-line: missing-fields]]
    {
      type = "flow",
      name = "outputs_flow",
      direction = "vertical"
    },
    { type = "empty-widget", style = "entity_frame_filler" }
  }--[[@as flib.GuiElemDef]])
  gui.frames.bpio_tabbed_pane.add_tab(gui.frames.data_tab, gui.data_container.data_flow)

  local i = 1
  local times = {}
  for j = 1,core.state.check_info.amount do
    times[#times+1] = {j*core.state.check_info.time/60,"m"}
  end
  for _, item_list in pairs(core.data.history) do
    if times[i] then
      draw_item_list(gui.data_container.inputs_flow, item_list, times[i][1], times[i][2])
    end
    i = i + 1
  end
  draw_item_list(gui.data_container.outputs_flow, core.data.output_list, core.state.check_info.amount*core.state.check_info.time/60, "m")
end



---@param core coreDict
function create_circuit_tab(gui,core)
  local qsignals = {}
  qsignals.state = core.aux.section.get_slot(1).value
  qsignals.pollution = core.aux.section.get_slot(2).value
  qsignals.on = core.aux.section.get_slot(3).value
  qsignals.off = core.aux.section.get_slot(4).value
  if not (qsignals.state and qsignals.pollution and qsignals.on and qsignals.off) then return end

  for _,sign in pairs(qsignals) do
    if sign.quality == nil then sign.quality="normal" end 
  end

  gui.circuit_container = flib.add(gui.frames.bpio_tabbed_pane,
  {
    type = "flow",
    direction = "vertical",
    name = "circuit_flow",
    style_mods = { padding = 12},
    {
      type = "flow",
      direction = "horizontal",
      {
        type = "label",
        name = "circuit_label",
        caption = {"gui-element.bpio-circuit-state-label" },
        style_mods = { top_margin = 10 }
      },
      {
        type = "choose-elem-button",
        name = "bpio-state-signal",
        elem_type = "signal",
        signal = qsignals.state
      },
    },
    {
      type = "flow",
      direction = "horizontal",
      {
        type = "label",
        name = "circuit_label",
        caption = {"gui-element.bpio-circuit-pollution-label" },
        style_mods = { top_margin = 10 }
      },
      {
        type = "choose-elem-button",
        name = "bpio-pollution-signal",
        elem_type = "signal",
        signal = qsignals.pollution
      },
    },
    {
      type = "flow",
      direction = "horizontal",
      {
        type = "label",
        name = "circuit_label",
        caption = {"gui-element.bpio-circuit-on-label" },
        style_mods = { top_margin = 10 }
      },
      {
        type = "choose-elem-button",
        name = "bpio-on-signal",
        elem_type = "signal",
        signal = qsignals.on
      },
    },
    {
      type = "flow",
      direction = "horizontal",
      {
        type = "label",
        name = "circuit_label",
        caption = {"gui-element.bpio-circuit-off-label" },
        style_mods = { top_margin = 10 }
      },
      {
        type = "choose-elem-button",
        name = "bpio-off-signal",
        elem_type = "signal",
        signal = qsignals.off
      },
    },
    { type = "empty-widget", style = "entity_frame_filler" }
  }--[[@as flib.GuiElemDef]])
  gui.frames.bpio_tabbed_pane.add_tab(gui.frames.circuit_tab, gui.circuit_container.circuit_flow)
end



---@param player LuaPlayer
---@param core coreDict
function draw_gui(player, core)
  if not is_valid_core(core, "both") then
    gui_kick_everyone(core)
    core_die(core) 
    return
  end

  local saved_tab
  if player.gui.screen["bpio_menu"] then
    if core.state.status == "on" then saved_tab = player.gui.screen["bpio_menu"]["mflow"]["divisor"]["rframe"]["right_inset"]["bpio_tabbed_pane"].selected_tab_index end
    player.gui.screen["bpio_menu"].destroy()
  end
  local sprite_name = core.aux.render_name
  local saved_sprite
  if sprite_name == "bpio-item-extractor" then
    saved_sprite = 1
  elseif sprite_name == "bpio-quantum-stabilizer" then
    saved_sprite = 2
  elseif sprite_name == "bpio-ai-trainer" then
    saved_sprite = 3
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

  if core.state.status == "booting" then
    booting_screen(gui,player,core)
  else
    create_tab_container(gui,player)
    create_control_tab(gui,core)
    create_surface_tab(gui,core)
    create_inventories_tab(gui,core)
    if core.state.status ~= "off" then
      create_data_tab(gui,core)
    end
    create_circuit_tab(gui,core)
    if saved_sprite then gui.control_container.bpio_sprite.selected_index = saved_sprite end
    if saved_tab then gui.frames.bpio_tabbed_pane.selected_tab_index = saved_tab end
  end
end