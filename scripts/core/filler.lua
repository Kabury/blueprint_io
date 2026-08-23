---@param core coreDict
function fill_area_with_colliders(core)
  if not (core.aux.projection_box.left_top.x and core.aux.projection_box.left_top.y and core.aux.projection_box.right_bottom.x and core.aux.projection_box.right_bottom.y) then return end  
  local width = core.aux.projection_box.right_bottom.x - core.aux.projection_box.left_top.x
  local height = core.aux.projection_box.right_bottom.y - core.aux.projection_box.left_top.y

  local grid = {}
  for x = 0, width - 1 do
      grid[x] = {}
      for y = 0, height - 1 do
          grid[x][y] = false
      end
  end

  local collider_sizes = {["1-collider"]=0.8,
                          ["2-collider"]=1.8,
                          ["3-collider"]=2.8,
                          ["4-collider"]=3.8,
                          ["5-collider"]=4.8,
                          ["6-collider"]=5.8,
                          ["7-collider"]=6.8,
                          ["8-collider"]=7.8,
                          ["9-collider"]=8.8,
                          ["10-collider"]=9.8}
  for name,size in pairs(collider_sizes) do
    collider_sizes[name] = size*2+0.4
  end 
  local weights = {}
  for name,size in pairs(collider_sizes) do
    weights[name] = math.ceil(1.4 ^ size)
  end


  local function can_place(target_x, target_y, collider_size)
    if target_x + collider_size > width or target_y + collider_size > height then return false end
    for x = target_x, target_x + collider_size - 1 do
      for y = target_y, target_y + collider_size - 1 do
        if grid[x][y] then return false end
      end
    end
    return true
  end

  local function mark_occupied(target_x, target_y, collider_size)
      for x = target_x, target_x + collider_size - 1 do
          for y = target_y, target_y + collider_size - 1 do
              grid[x][y] = true
          end
      end
  end

  for y = 0, height - 1 do
    for x = 0, width - 1 do
      if not grid[x][y] then
        
        local valid_sizes = {}
        local total_weight = 0
        for name,size in pairs(collider_sizes) do
          if can_place(x, y, size) then
            table.insert(valid_sizes, {name,size})
            total_weight = total_weight + weights[name]
          end
        end

        if #valid_sizes > 0 then
          local chosen_size = valid_sizes[1][2]
          if total_weight > 0 then
            local roll = math.random(1, total_weight)
            local current_sum = 0
            for _, size_tuple in pairs(valid_sizes) do
              current_sum = current_sum + weights[size_tuple[1]]
              if roll <= current_sum then
                chosen_size = size_tuple
                break
              end
            end
          end
          local spawn_x = core.aux.projection_box.left_top.x + x + (chosen_size[2] / 2)
          local spawn_y = core.aux.projection_box.left_top.y + y + (chosen_size[2] / 2)
          
          core.aux.surface.create_entity{
            name = chosen_size[1],
            position = {spawn_x, spawn_y},
            force = "neutral"
          }

          mark_occupied(x, y, chosen_size[2])
        end
      end
    end
  end
end

---@param core coreDict
function clear_area_from_colliders(core)
  local ending = "-collider"
  local collider_names = {}
  for i = 1,10 do
    collider_names[#collider_names + 1] = tostring(i)..ending
  end
  local colliders = core.aux.surface.find_entities_filtered{area = core.aux.projection_box,name=collider_names}
  for _,entity in pairs(colliders) do
    entity.destroy()
  end
end