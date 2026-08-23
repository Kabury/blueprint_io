---@param core coreDict
---@param mode "entities"|"inventories"|"both"
function is_valid_core(core,mode)
  if not core then return false end
  local entities_check = true
  if mode == "entities" or mode == "both" then
    for _,entity in pairs(core.ent) do
      entities_check = entities_check and entity.valid
    end
  end

  local inventories_check = true
  if mode == "inventories" or mode == "both" then
    for _,inventory in pairs(core.inv) do
      inventories_check = inventories_check and inventory.valid   
    end
  end

  return entities_check and inventories_check
end



---@param core coreDict
function core_die(core)
  if not core.state.lock then
    core.state.lock = true
    core.inv.blueprint.destroy()
    if core.ent.output.valid   then core.ent.output.die()   else core.ent.output.destroy()   end
    if core.ent.input.valid    then core.ent.input.die()    else core.ent.input.destroy()    end
    if core.ent.building.valid then core.ent.building.die() else core.ent.building.destroy() end
    if core.ent.core.valid     then core.ent.core.die()     else core.ent.core.destroy()     end
    local ids = core.ids
    for _,id in pairs(ids) do
      storage.dictionary.core[id]=nil
    end
  end
end



---@param core coreDict
function core_destroy(core)
  if not core.state.lock then
    core.state.lock = true
    core.inv.blueprint.destroy()
    core.ent.output.destroy()
    core.ent.input.destroy()
    core.ent.building.destroy()
    core.ent.core.destroy()
    local ids = core.ids
    for _,id in pairs(ids) do
      storage.dictionary.core[id]=nil
    end
  end
end



---@param core coreDict
function surface_shutdown(core)
  local name = "bpio-"..core.ids.core
  game.delete_surface(name)
  game.merge_forces(name,core.aux.force)
  core.aux.force.print("Shutting dimension down")
  core.sim = {}
end



---@param core coreDict
function refund_cost(core)
  for _,item_format in pairs(core.data.cost) do
    core.inv.building.insert(item_format)
  end
  core.aux.force.print("Refunded buildings")
end



---@param core coreDict
function surface_recall(core)
  refund_cost(core)
  surface_shutdown(core)
end



---@param core coreDict
function validate_blueprint(core)
  local blueprint = core.inv.blueprint[1]
  if not (blueprint and blueprint.valid_for_read and blueprint.is_blueprint ) then
    core.aux.force.print("Invalid blueprint slot")
    return false
  end

  if not blueprint.is_blueprint_setup() then
    core.aux.force.print("Invalid blueprint slot")
    return false
  end

  local target_size = blueprint.blueprint_snap_to_grid 
  if target_size == nil or target_size.x == nil or target_size.y == nil then
    core.aux.force.print("Blueprint needs to have relative snapping enabled")
    return false
  end

  local source_surface = core.aux.surface
  local mgs = source_surface.map_gen_settings
  local source_size = {x=mgs.width,y=mgs.height}

  if target_size.x > source_size.x or target_size.y > source_size.y then
    core.aux.force.print("This ribbon surface doesn't support a blueprint this wide/tall")
    return false
  end

  if blueprint.blueprint_absolute_snapping then
    core.aux.force.print("Blueprint has absolute snapping. Needs to be relative")
    return false
  end

  return true, target_size
end