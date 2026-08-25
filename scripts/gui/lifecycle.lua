---@param core coreDict
function gui_kick_everyone(core)
  if not core then return end
  for viewer,opened in pairs(storage.dictionary.player) do
    if opened == core.ids.core then
      local lua_viewer = game.get_player(viewer)
      if lua_viewer then
        if lua_viewer.gui.screen["bpio_menu"] then
          lua_viewer.gui.screen["bpio_menu"].destroy()
        end
      end
      storage.dictionary.player[viewer]=nil
    end
  end
end



---@param core coreDict
function redraw_everyone(core)
  for viewer,opened in pairs(storage.dictionary.player) do
    if opened == core.ids.core then
      local lua_viewer = game.get_player(viewer)
      if lua_viewer then
        draw_gui(lua_viewer,core)
      end 
    end
  end
end



---@param event EventData.on_gui_opened
function bpio_open(event)
  local entity = event.entity
  if not 
  ( event.gui_type == defines.gui_type.entity and entity ~= nil and
    entity.name and entity.name == "bpio-core" ) 
  then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local id_core = entity.unit_number
  local dicts = storage.dictionary
  if not dicts then return end

  draw_gui(player, dicts.core[id_core])
  dicts.player[player.index]=id_core
end



---@param event EventData.on_gui_closed
function bpio_close(event)
  if not (event.element and event.element.name == "bpio_menu") then return end  
  
  local player = game.get_player(event.player_index)
  if not player then return end
  
  event.element.destroy()
  storage.dictionary.player[player.index]=nil
end



---@param event EventData.on_player_controller_changed
function bpio_controller(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local dicts = storage.dictionary
  if not dicts then return end
  if dicts.player[player.index] == nil then return end

  local id_core = dicts.player[player.index]
  draw_gui(player, dicts.core[id_core])
end



---@param event EventData.on_gui_click
function handle_buttons(event)
  local start_boot = event.element.name == "bpio-start-boot"
  local force_off = event.element.name == "bpio-force-off"
  local turn_off = event.element.name == "bpio-turn-off"
  local turn_on = event.element.name == "bpio-turn-on"
  local to_standby = event.element.name == "bpio-to-standby"
  local direction_change = event.element.name:match("^bpio%-direction%-(.+)$")
  local glance = event.element.name == "bpio-blueprint-glance"
  if not (start_boot or force_off or turn_off or turn_on or to_standby or direction_change or glance) then return end

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

  elseif force_off then
    surface_recall(core) -- this will call refund_cost inside too
    bpio_off(core)

  elseif turn_off then
    refund_cost(core)
    bpio_off(core)

  elseif turn_on then
    bpio_on(core,event)

  elseif to_standby then
    bpio_standby(core)

  elseif direction_change then
    core.aux.projector_direction = direction_change --[[@as corners]]
  end

  redraw_everyone(core)

  if glance then
    if core.inv.blueprint[1].valid_for_read and core.inv.blueprint[1].is_blueprint then
      player.opened = core.inv.blueprint[1]
    end
  end
end



---@param event EventData.on_gui_value_changed
function handle_sliders(event)
  local time = event.element.name == "bpio-check-time-slider"
  local amount = event.element.name =="bpio-check-amount-slider"
  if not (time or amount) then return end

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

  local side_box
  if time then 
    side_box = event.element.parent["bpio-check-time-box"]
    core.state.check_info.time = event.element.slider_value
  elseif amount then 
    side_box = event.element.parent["bpio-check-amount-box"]
    core.state.check_info.amount = event.element.slider_value 
  end
  side_box.text = tostring(event.element.slider_value)
end



---@param event EventData.on_gui_text_changed
function handle_textboxes(event)
  local amount = event.element.name == "bpio-check-amount-box"
  local time = event.element.name == "bpio-check-time-box"
  if (not (amount or time)) or event.element.text =="" then return end

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
  
  
  local side_slide
  local raw_number = tonumber(event.element.text)
  local refined_number
  if time then 
    side_slide = event.element.parent["bpio-check-time-slider"]
    refined_number = math.min(math.max(raw_number, 10), 300)
    core.state.check_info.time = refined_number
  elseif amount then 
    side_slide = event.element.parent["bpio-check-amount-slider"]
    refined_number = math.min(math.max(raw_number, 1), 10)
    core.state.check_info.amount = refined_number
  end
  event.element.text = tostring(refined_number)
  side_slide.slider_value = refined_number

end



---@param event EventData.on_gui_selection_state_changed
function bpio_sprites(event)
  if event.element.name ~= "bpio_sprite" then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local dicts = storage.dictionary --[[@as dictionaryDict]]
  if not dicts then return end

  local id_core = dicts.player[player.index]

  local core = dicts.core[id_core]
  if not is_valid_core(core,"both") then
    core_die(core)
    return
  end
  
  local sprite_id = event.element.selected_index
  local sprite_name
  if sprite_id == 1 then
    sprite_name = "bpio-item-extractor"
  elseif sprite_id == 2 then
    sprite_name = "bpio-quantum-stabilizer"
  elseif sprite_id == 3 then
    sprite_name = "bpio-ai-trainer"
  end
  local core_anim_status = core.state.status
  if core_anim_status == "standby" or core_anim_status == "booting" then
    core_anim_status = "off"
  end
  core_anim_status = "-"..core_anim_status
  
  core.aux.render_name = sprite_name
  core.aux.rendering.destroy()
  core.aux.rendering = rendering.draw_animation{animation=sprite_name..core_anim_status,target=core.ent.core, surface=core.aux.surface}
  

end


---@param event EventData.on_gui_elem_changed
function bpio_signals(event)
  local ename = event.element.name
  local state = ename == "bpio-state-signal"  
  local pollution = ename == "bpio-pollution-signal"  
  local on = ename == "bpio-on-signal"
  local off = ename == "bpio-off-signal"

  if not (state or pollution or on or off) then return end

  local player = game.get_player(event.player_index)
  if not player then return end

  local dicts = storage.dictionary --[[@as dictionaryDict]]
  if not dicts then return end

  local id_core = dicts.player[player.index]

  local core = dicts.core[id_core]
  if not is_valid_core(core,"both") then
    core_die(core)
    return
  end
  
  local where
  if state then
    where = 1
  elseif pollution then
    where = 2
  elseif on then
    where = 3
  elseif off then
    where = 4
  else
    return 
  end

  local stale = core.aux.section.get_slot(where).min
  local qsignal = event.element.elem_value
  if not qsignal then return end
  if qsignal.quality == nil then qsignal.quality="normal" end 

  core.aux.section.set_slot(where,{min=stale,max=stale,value=qsignal --[[@as SignalFilter]]})

  if (on and core.state.status ~= "on") or (off and core.state.status == "on") then
    core.ent.trigger.get_or_create_control_behavior().circuit_condition = {first_signal = qsignal, comparator = "!=", constant=0}
  end
end