--- Library

---@class coreDict
---@field core LuaEntity the core entity in the map
---@field blueprint LuaInventory Inventory for the blueprint slot
---@field building LuaInventory Inventory for the buildings for the blueprint
---@field input LuaInventory Inventory to check incoming items
---@field output LuaInventory Inventory to check outgoing items



--- Initialize the storage and register all of our entities on the map. If settings change, register them again.

local function init_storage()
    storage.where = {}
    storage.coreDictionaries = {off={},booting={},on={}}
    storage.queue = {booting={},on={}}
end

local function init_entities()
  local clock = game.tick
  local i = 1
  local where = {}
  local coreDictionaries = {off={},booting={},on={}}
  local queue = {booting={},on={}}

  for _, surface in pairs(game.surfaces) do
    local cores = surface.find_entities_filtered{name={"bpio-core"}}

    for _, core in pairs(cores) do
      local id = core.unit_number
      if id == nil then
          goto continue
      end
      where[id]="off"
      coreDictionaries.off[id]=core
      ::continue::
    end
  end

  storage.where = where
  storage.coreDictionaries = coreDictionaries
  storage.queue = queue
end


script.on_init(function()
    init_storage()
    init_entities()
end)

local function reorganize(event)
    if event.setting == "bpio-stagger" then init_entities() end
end

script.on_event(defines.events.on_runtime_mod_setting_changed, reorganize)



--- Build our compound entity

local function OnSiteCreated(event)
    if event.effect_id ~= "bpio-built-event" then return end
    ---@type LuaEntity
    local core = event.target_entity
    local id = core.unit_number
    storage.where[id]="off"
    ---@type coreDict
    storage.coreDictionaries.off[id] = 
    {
      core      = core,
      blueprint = game.create_inventory(1),
      building  = game.create_inventory(40), 
      input     = game.create_inventory(5),
      output    = game.create_inventory(5)
    }
    storage.coreDictionaries.off[id].blueprint.insert({name="iron-plate"})
end

script.on_event(defines.events.on_script_trigger_effect, OnSiteCreated)



--- GUI stuff

script.on_event(defines.events.on_gui_opened, function(event)
  if event.gui_type ~= defines.gui_type.entity or not event.entity then return end

  local entity = event.entity
  if entity == nil then return end
  local name = entity.name

  if name ~= "bpio-core" then return end

  local player = game.get_player(event.player_index)
  if player == nil then return end
  --Avoid duplicates
  if player.gui.relative["bpio-menu"] then
    player.gui.relative["bpio-menu"].destroy()
  end

  local id = entity.unit_number
  local where = storage.where[id]
  ---@type coreDict
  local coreDictionary = storage.coreDictionaries[where][id]
  
  if coreDictionary ~= nil and where == "off" then
    local frame = player.gui.relative.add{
      type = "frame",
      name = "bpio-menu",
      caption = { "gui-element.gui-title" },
      anchor = 
      {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.left,
        name = "bpio-core"
      },
      direction = "vertical"
    }
    if coreDictionary.blueprint.valid and coreDictionary.blueprint.object_name=="LuaInventory" and #coreDictionary.blueprint > 0  then

      local shallow = frame.add
      {
        type="frame",
        name="shallow",
        style = "shallow_frame"
      }

      local blueprint = shallow.add 
      {
        type = "inventory",
        inventory= coreDictionary.blueprint,
        direction = "horizontal",
        slots_per_row = 1,
        handle_cursor_transfer = true,
        handle_cursor_split = true,
        handle_open_item = true
      }
      
    end
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
    if event.element.name ~= "bpio-simulate" then return end

    local player = game.get_player(event.player_index)
    if player == nil then return end
    local force = player.force
    local core = player.opened
    if not (core and core.valid) then return end
    local id = core.unit_number
    local compound = storage.compounds.dormant[id]
    if compound ~= nil then 
        if compound.dcore.valid and compound.blueprint.valid and compound.materials.valid and compound.inputs.valid and compound.outputs.valid then
            local surface = core.surface
            local place = core.position

            local active_core = surface.create_entity{name="bp-core-active",force=force,position={place.x, place.y}}
            if active_core ~= nil then
                core.destroy()
            else
                return
            end
            id = active_core.unit_number
            if id == nil then
                return
            end
            local new_compound = {acore=active_core,blueprint=compound.blueprint,materials=compound.materials,inputs=compound.inputs,outputs=compound.outputs}
            storage.compounds.active[id] = new_compound
            storage.compounds.dormant[id] = nil
        else
            die_compound(compound,force)
        end
    end
end)

--- Update our entities

