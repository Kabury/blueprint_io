
local meld = require("meld")
local created_eff =
{
  type = "direct",
  action_delivery =
  {
    type = "instant",
    target_effects =
    {
      {type = "script", effect_id = "bpio-built-event"}
    }
  }
}

local box = {{-2.3, -2.3}, {2.3, 2.3}}
local boxes = {selection_box=box,collision_box=box}

local scale=48/32
local height=127
local width=156
local shift={1.5,0.25}

local bpio_core =
{
  name="bpio-core",
  created_effect=created_eff,
  inventory_size=0,
  picture=
  {
    layers=
    {
      [1]={filename="__blueprint_io__/graphics/entity/market.png",height=height,width=width,scale=scale,shift=shift}
    }
  }
}
local bpio_input =
{
  name="bpio-input",
  inventory_type="with_filters_and_bar",
  inventory_size=5,
  picture=
  {
    layers=
    {
      [1]={filename="__blueprint_io__/graphics/entity/input_market.png",height=height,width=width,scale=scale,shift=shift}
    }
  }
}
local bpio_output =
{
  name="bpio-output",
  inventory_type="with_filters_and_bar",
  inventory_size=5,
  picture=
  {
    layers=
    {
      [1]={filename="__blueprint_io__/graphics/entity/output_market.png",height=height,width=width,scale=scale,shift=shift}
    }
  }
}


bpio_core = meld.meld(bpio_core,boxes)
bpio_input = meld.meld(bpio_input,boxes)
bpio_output = meld.meld(bpio_output,boxes)

data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_core)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_input)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_output)})


