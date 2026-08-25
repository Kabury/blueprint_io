---@param core coreDict
function bpio_charge(core)
  for _,item_format in pairs(core.data.input) do
    local actual_amount = core.inv.input.remove(item_format)
    core.aux.statistics.on_flow(item_format --[[@as FlowStatisticsID ]],-actual_amount)
  end
end



---@param core coreDict
function bpio_pay(core)
  for _,item_format in pairs(core.data.output) do
    local actual_amount = core.inv.output.insert(item_format)
    core.aux.statistics.on_flow(item_format --[[@as FlowStatisticsID ]],actual_amount)
  end
end