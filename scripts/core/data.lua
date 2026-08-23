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



---@param core coreDict
---@param target_size {x: number, y: number}
---@param direction "right-top"|"left-top"|"right-bottom"|"left-bottom"
function bpio_corners(core, target_size, direction)
  local bx = core.aux.position.x
  local by = core.aux.position.y

  local base = {}
  base["right-top"]    = { bx + 7, by - 7 }
  base["left-top"]     = { bx - 7, by - 7 }
  base["right-bottom"] = { bx + 7, by + 7 }
  base["left-bottom"]  = { bx - 7, by + 7 }

  local tx = target_size.x
  local ty = target_size.y
  local offsets = {}
  offsets["right-top"]    = { 0, -(ty+2), (tx+2), 0 }
  offsets["left-top"]     = { -(tx+2), -(ty+2), 0, 0 }
  offsets["right-bottom"] = { 0, 0, (tx+2), (ty+2) }
  offsets["left-bottom"]  = { -(tx+2), 0, 0, (ty+2) }

  local b = base[direction]
  local o = offsets[direction]

  local left_top     = { x=b[1] + o[1], y=b[2] + o[2] }
  local right_bottom = { x=b[1] + o[3], y=b[2] + o[4] }

  return { left_top=left_top, right_bottom=right_bottom }
end



---@param core coreDict
---@param box BoundingBox
function bpio_interference(core,box)

  local obstructors = core.aux.surface.find_entities(box)
  
  if next(obstructors) then
    core.aux.force.print("Something is blocking the blueprint from being simulated in the surface:")
    core.aux.force.print(serpent.block({obstructors,#obstructors}))
    return false
  end


  local bad_tiles = core.aux.surface.find_tiles_filtered{
    area = box,
    collision_mask = "ground_tile",
    invert = true
  }
  if next(bad_tiles) then
    core.aux.force.print("Something is blocking the blueprint from being simulated in the surface (Tiles):")
    core.aux.force.print(serpent.block({bad_tiles, #bad_tiles}))
    return false
  end

  return true
end