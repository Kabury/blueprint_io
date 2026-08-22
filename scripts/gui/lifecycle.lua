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



---@param event EventData.on_gui_elem_changed
function bpio_signals(event)
  local ename = event.element.name
  local state = ename == "bpio-state-signal"  
  local pollution = ename == "bpio-pollution-signal"  

  if not (state or pollution) then return end

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
  else
    return 
  end

  local stale = core.aux.section.get_slot(where).min
  local qsignal = event.element.elem_value
  if not qsignal then return end
  if qsignal.quality == nil then qsignal.quality="normal" end 

  core.aux.section.set_slot(where,{min=stale,max=stale,value=qsignal --[[@as SignalFilter]]})
end