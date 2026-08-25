--===== Library
flib = require("__flib__.gui")

kl = require("__klib__.runtime_stage")  

require("scripts/types")
require("scripts/item_formats")
require("scripts/simulation")
require("scripts/work")
require("scripts/core/data")
require("scripts/core/world")
require("scripts/core/filler")
require("scripts/gui/utils")
require("scripts/gui/lifecycle")
require("scripts/gui/rendering")


local BAR_FREQUENCY = 10
local bpio_filter = 
{
    { filter = "name", name = "bpio-core" },
    { filter = "name", name = "bpio-core-building" },
    { filter = "name", name = "bpio-core-input" },
    { filter = "name", name = "bpio-core-output" },
}


--===== Initialization

local function init_storage()
  storage.dictionary = { core = {}, player = {} }
  storage.queue = {}
end

script.on_init(init_storage)

---@param event EventData.on_runtime_mod_setting_changed
local function reorganize(event)
  if event.setting == "bpio-stagger" then 
  end
end

script.on_event(defines.events.on_runtime_mod_setting_changed, reorganize)


--===== Entity Lifecycle

script.on_event(defines.events.on_script_trigger_effect, on_bpio_created_or_wired)

script.on_event(defines.events.on_player_mined_entity, on_bpio_mined,bpio_filter)
script.on_event(defines.events.on_robot_mined_entity, on_bpio_mined,bpio_filter)
script.on_event(defines.events.on_entity_died, on_bpio_killed,bpio_filter)


--===== Functions for GUI

script.on_event(defines.events.on_player_display_resolution_changed, adjust_gui_size)
script.on_event(defines.events.on_player_display_scale_changed, adjust_gui_size)
script.on_event(defines.events.on_player_display_density_scale_changed, adjust_gui_size)




--===== GUI Lifecycle

script.on_event(defines.events.on_gui_opened, bpio_open)
script.on_event(defines.events.on_gui_closed, bpio_close)
script.on_event(defines.events.on_player_controller_changed, bpio_controller)


--===== GUI Actions

script.on_event(defines.events.on_gui_click, handle_buttons)

script.on_event(defines.events.on_gui_value_changed, handle_sliders)

script.on_event(defines.events.on_gui_text_changed, handle_textboxes)

script.on_event(defines.events.on_gui_selection_state_changed, bpio_sprites)

script.on_event(defines.events.on_gui_inventory_action, inventory_interaction)

script.on_event(defines.events.on_gui_elem_changed, bpio_signals)



--====================
--===== Queueing =====
--====================

local function on_tick(event)
  local clock = event.tick

  ---@type coreID[]
  local cores_now = storage.queue[clock]
  if not cores_now then return end

  for _, id_core in pairs(cores_now) do
    ---@type dictionaryDict
    local dicts = storage.dictionary
    if not dicts then return end
    local core =  dicts.core[id_core]
    if not core then return end

    if core.state.status == "booting" then
      local todo = core.state.sim_lock
      local sim = core.sim
      if todo == "build_ghosts" then
        local blueprint = core.inv.blueprint[1]
        local ghosts = blueprint.build_blueprint{surface=sim.surface,force=sim.force, position={0,0}}
        if next(ghosts) then 
          sim.ghosts = ghosts
          core.state.sim_lock = "build_entities"
          local time_slice = kl.get_or_set(storage.queue,clock+1)
          time_slice[#time_slice+1] = id_core
          core.aux.force.print("Placed ghosts")
        else
          core.aux.force.print("Could not build ghosts. Recalling")
          surface_recall(core)
        end
      end
      if todo == "build_entities"then
        if sim.ghosts and sim.plan_memory then 
          
          ::retry::
          local at_least_one = false

          for ghostid,ghost in pairs(sim.ghosts) do
            local _, revenant, proxy = ghost.revive{raise_revive = true}

            if revenant then
              at_least_one = true
              
              if proxy then
                for _,plan in pairs(proxy.insert_plan) do
                  begin_plan(plan,revenant,sim.plan_memory)
                end
                proxy.destroy()
              end

              sim.ghosts[ghostid]=nil
            end
          end

          if next(sim.ghosts) then
            if at_least_one then 
              goto retry 
            else
              core.aux.force.print("The blueprint has something unbuildable. Recalling")
              surface_recall(core)
            end
          else
            core.state.sim_lock = "initialize_logs"
            local time_slice = kl.get_or_set(storage.queue,clock+1)
            time_slice[#time_slice+1] = id_core
            core.aux.force.print("Built entities")
          end
        end
      end
      if todo == "initialize_logs" then
        local input_watcher = sim.surface.find_entities_filtered{name = "bpio-blueprintable-input"}
        local output_watcher = sim.surface.find_entities_filtered{name = "bpio-blueprintable-output"}                                                                                                                                        
        
        if #input_watcher==1 and #output_watcher==1 then
          sim.input_watcher = input_watcher[1].get_inventory(defines.inventory.chest)
          sim.output_watcher = output_watcher[1].get_inventory(defines.inventory.chest)

          if sim.input_watcher and sim.output_watcher then
            for _,item_format in pairs(core.data.input) do
              sim.input_watcher.insert(item_format)
            end
            core.state.sim_lock = "busy"
            local time_slice = kl.get_or_set(storage.queue,clock+1)
            time_slice[#time_slice+1] = id_core
            core.aux.force.print("Spawned items.")
            core.aux.force.print("Began logging...")
          end
        else
          core.aux.force.print("Couldn't find the input/output boxes for some reason. Recalling")
          surface_recall(core)
        end
      end
      if todo == "busy" then
        core.state.progress = core.state.progress + 1
        if core.state.progress % ((core.state.check_info.time*60) / BAR_FREQUENCY) == 0 then
          core.state.check = core.state.check + 1
          if sim.input_watcher and sim.input_watcher.valid then
            local current_input = sim.input_watcher.get_contents() --[[@as ItemStackDefinition[] ]]
            if current_input then
              local current_list = as_item_list(current_input)
              core.data.history[core.state.check] = items_consumed(core.data.input_list,current_list)
            end
          else
            core.aux.force.print("Couldn't find the input box running. Recalling")
            surface_recall(core)
          end 
        end
        for _,progress_bar in pairs(core.aux.progress_bars) do
          if progress_bar.valid then 
            progress_bar.value = core.state.progress * BAR_FREQUENCY/(core.state.check_info.time*core.state.check_info.amount*60) 
          end
        end
        if core.state.check == core.state.check_info.amount then
          if sim.output_watcher and sim.output_watcher.valid then
            local output = sim.output_watcher.get_contents() --[[@as ItemStackDefinition[] ]]
            end_plan(sim.plan_memory)
            core.data.output = output
            core.data.output_list = as_item_list(output)
            core.aux.section.set_slot(1,{min=3,max=3,value=core.aux.section.get_slot(1).value})
            core.state.sim_lock = "epilog"
            local time_slice = kl.get_or_set(storage.queue,clock+1)
            time_slice[#time_slice+1] = id_core
            core.aux.force.print("Finishing logging...")
          else
            core.aux.force.print("Couldn't find the output box running. Recalling")
            surface_recall(core)
          end
        else
          local time_slice = kl.get_or_set(storage.queue,clock+BAR_FREQUENCY)
          time_slice[#time_slice+1] = id_core
        end
      end
      if todo == "epilog" then
        core.state.status = "standby"
        local stolen_goods = items_consumed(
          as_item_list(sim.plan_memory.beggining),
          as_item_list(sim.plan_memory.ending)
          )
        core.data.history[#core.data.history] = add_item_lists(core.data.history[#core.data.history],stolen_goods)
        core.data.input = as_item_quality_count(core.data.history[#core.data.history])
        local pollution_stats = game.get_pollution_statistics(sim.surface)
        local pollutants = pollution_stats.input_counts
        local total_pollution = 0
        for _,pol in pairs(pollutants) do
          total_pollution = total_pollution + pol
        end
        core.data.pollution = total_pollution
        pollution_stats.clear()
        core.state.sim_lock = nil
        core.state.check = 0
        core.aux.section.set_slot(2,{value=core.aux.section.get_slot(2).value,min=core.data.pollution*10,max=core.data.pollution*10})
        surface_shutdown(core)
        redraw_everyone(core)
      end
    elseif core.state.status == "on" then

      if not is_valid_core(core,"both") then 
        gui_kick_everyone(core)
        core_die(core)
        goto next_core 
      end

      if core.state.check == 0 then 
        core.state.checks={}
        for i = 1, core.state.check_info.amount do
          core.state.checks[#core.state.checks + 1] = "?"
        end
      end
      core.state.check = core.state.check+1

      local current_items = as_item_list(core.inv.input.get_contents()  --[[@as ItemStackDefinition[] ]])
      local current_target = core.data.history[core.state.check]
      if current_target then
        if is_super_set(current_items,current_target) then
          core.state.checks[core.state.check] = "y" 
        else
          core.state.checks[core.state.check] = "n"
          if settings.global["bpio-damage"].value then 
            core.ent.core.damage(10,"neutral",nil,nil,core.ent.core) 
          end
          if not is_valid_core(core,"both") then 
            gui_kick_everyone(core)
            core_die(core)
            goto next_core 
          end
        end
      else
        core.aux.force.print("Core "..core.ids.core.." could not find it's history entry. It might have corrupted.")
      end
      
      if core.state.check == core.state.check_info.amount then    
        local every_check = true
        for _,check in pairs(core.state.checks) do
          if check ~= "y" then
            every_check = false
            break
          end
        end

        if every_check or settings.global["bpio-consumption"].value then
          bpio_charge(core)
          core.aux.surface.pollute(core.aux.position,core.data.pollution,core.ent.core) 
        end
    
        if every_check then  
          bpio_pay(core)
        end
    
        core.state.check = 0
      end
      
      local future_slice = kl.get_or_set(storage.queue,clock+core.state.check_info.time*60)
      future_slice[#future_slice+1] = id_core
      redraw_everyone(core)
    end
    ::next_core::
  end
end


script.on_event(defines.events.on_tick, on_tick)
