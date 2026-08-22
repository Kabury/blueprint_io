function formatString(str)
    local result = str:gsub("-", " ")
    result = result:gsub("^%l", string.upper)
    return result
end



---@param gui_element LuaGuiElement
---@param item_list itemList
---@param time? number
---@param unit? "s"|"m"|"h"
function draw_item_list(gui_element, item_list,time,unit)
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



---@param event EventData.on_player_display_resolution_changed|EventData.on_player_display_scale_changed|EventData.on_player_display_density_scale_changed
function adjust_gui_size(event)
  local player = game.get_player(event.player_index)
  if not player then return end

  local id_core = storage.dictionary.player[player.index]
  if id_core then
    local core = storage.dictionary.core[id_core]
    if core and player.gui.screen["bpio_menu"] then
      draw_gui(player, core)
    end
  end
end



---@param event EventData.on_gui_inventory_action
---@param from LuaInventory
---@param to LuaInventory
function handle_inventory_click(event,from,to)
  local slot = from[event.slot]
  if not slot then return end
  
  if event.control then
    if slot.valid_for_read then
      to.transfer_from_inventory(from,{ name = slot.name, quality =  slot.quality.name or "normal", comparator = "=" })
    else
      to.transfer_from_inventory(from)
    end
  elseif event.shift then
    if slot.valid_for_read then
      to.transfer_from_stack(slot)
    end
  end
end


---@param event EventData.on_gui_inventory_action
function inventory_interaction(event)
  if not event.element then return end
  
  local is_player = event.element.name == "bpio_player_inventory"
  local is_core = event.element.name == "bpio_blueprint_inventory" or
                            event.element.name == "bpio_building_inventory" or
                            event.element.name == "bpio_input_inventory" or
                            event.element.name == "bpio_output_inventory"
  if not (is_player or is_core) then return end
  
  local player = game.get_player(event.player_index)
  if not player then return end

  local player_inventory = player.get_main_inventory()
  if not player_inventory then return end

  if is_player then
    ---@type dictionaryDict
    local dict = storage.dictionary
    local id_core = dict.player[event.player_index]
    local core = dict.core[id_core]
    if not (core and is_valid_core(core,"inventories")) then return end
    local buildings_inventory = core.inv.building
    handle_inventory_click(event,player_inventory,buildings_inventory)
  elseif is_core then
    local core_inventory = event.element.inventory
    if not core_inventory then return end
    handle_inventory_click(event,core_inventory,player_inventory)
  end
end

