---@param item_array ItemStackDefinition[]
function as_item_list(item_array)
  ---@type itemList
  local item_list = {}
  for _,item_format in pairs(item_array) do
    local item_table = kl.get_or_set(item_list,item_format.name)
    if item_format.quality and item_format.count then
      item_table[item_format.quality] = (item_table[item_format.quality] or 0) + item_format.count
    else
      game.print("As item list failed")
    end
  end
  return item_list
end



---@param item_list itemList
function as_item_quality_count(item_list)
  ---@type ItemStackDefinition[]
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
function is_super_set(super_list,sub_list)
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
function items_consumed(before,after)
  ---@type itemList
  local difference = {}
	for name,qcounts in pairs(before) do
    difference[name] = {}
    if not after[name] then after[name] = {} end
    for quality,count in pairs(qcounts) do
      difference[name][quality] = count - (after[name][quality] or 0)
    end
	end

  for name,qcounts in pairs(difference) do
    for quality,count in pairs(qcounts) do
      if count == 0 then
        difference[name][quality] = nil
      end
    end
  end
  return difference
end



---@param first itemList
---@param second itemList
function add_item_lists(first,second)
  ---@type itemList
  local both = {}
  for name,qcounts in pairs(first) do
    both[name] = {}
    for quality,count in pairs(qcounts) do
      both[name][quality] = count
    end
  end

  for name,qcounts in pairs(second) do
    local temp_name = kl.get_or_set(both,name)
    for quality,count in pairs(qcounts) do
      both[name][quality] = (temp_name[quality] or 0) + count
    end
  end
  return both
end