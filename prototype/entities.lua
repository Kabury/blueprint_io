
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

local icon_size = 32
local scale=48/32
local height=127
local width=156
local shift={1.5,0.25}
local inv_type = "with_custom_stack_size"
local inv_size = 5
local inv_prop = {stack_size_multiplier = 100, with_bar = true}

local noresult = {result=meld.delete()}


local bpio_site =
{
  name="bpio-site",
  created_effect=created_eff,
  collision_box={{-7.3, -2.3}, {7.3, 2.3}},
  icons={{icon="__blueprint_io__/graphics/icons/market.png",icon_size=icon_size,scale=scale,shift=shift}},
  picture=
  {
    layers=
    {
      [3]={filename="__blueprint_io__/graphics/entity/market.png",height=height,width=width,scale=scale,shift=shift},
      [1]={filename="__blueprint_io__/graphics/entity/input_market.png",height=height,width=width,scale=scale,shift={1.5-5,0.25}},
      [4]={filename="__blueprint_io__/graphics/entity/output_market.png",height=height,width=width,scale=scale,shift={1.5+5,0.25}}
    }
  }
}
local bpio_core =
{
  name="bpio-core",
  minable={result="bpio-site"},
  icons={{icon="__blueprint_io__/graphics/icons/market.png",icon_size=icon_size,scale=scale,shift=shift}},
  picture=
  {
    layers=
    {
      [1]={filename="__blueprint_io__/graphics/entity/market.png",height=height,width=width,scale=scale,shift=shift}
    }
  }
}
local bpio_internal_input =
{
  name="bpio-internal-input",
  inventory_type=inv_type,
  inventory_size=inv_size,
  inventory_properties={stack_size_multiplier=100},
  collision_box={{0, 0}, {0, 0}},
  selection_box={{-0.3, -0.3}, {0.3, 0.3}},
  minable=noresult,
  icons={{icon="__blueprint_io__/graphics/icons/input_market.png",icon_size=icon_size,scale=scale,shift=shift}},
  picture=
  {
    layers=
    {
      [1]={filename="__core__/graphics/empty.png",height=1,width=1,scale=scale,shift=shift}
    }
  }
}
local bpio_input =
{
  name="bpio-input",
  inventory_type=inv_type,
  inventory_size=inv_size,
  inventory_properties=inv_prop,
  minable=noresult,
  icons={{icon="__blueprint_io__/graphics/icons/input_market.png",icon_size=icon_size,scale=scale,shift=shift}},
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
  inventory_type=inv_type,
  inventory_size=inv_size,
  inventory_properties=inv_prop,
  minable=noresult,
  icons={{icon="__blueprint_io__/graphics/icons/output_market.png",icon_size=icon_size,scale=scale,shift=shift}},
  picture=
  {
    layers=
    {
      [1]={filename="__blueprint_io__/graphics/entity/output_market.png",height=height,width=width,scale=scale,shift=shift}
    }
  }
}
local bpio_input_watcher =
{
  name="bpio-input-watcher",
  minable={result="bpio-input-watcher"},
  inventory_type=inv_type,
  inventory_size=inv_size,
  inventory_properties=inv_prop,
  icons={{icon="__blueprint_io__/graphics/icons/input_market.png",icon_size=icon_size,scale=scale,shift=shift}},
  picture=
  {
    layers=
    {
      [1]={filename="__blueprint_io__/graphics/entity/input_market.png",height=height,width=width,scale=scale,shift=shift}
    }
  }
}
local bpio_output_watcher =
{
  name="bpio-output-watcher",
  minable={result="bpio-output-watcher"},
  inventory_type=inv_type,
  inventory_size=inv_size,
  inventory_properties=inv_prop,
  icons={{icon="__blueprint_io__/graphics/icons/output_market.png",icon_size=icon_size,scale=scale,shift=shift}},
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
bpio_input_watcher = meld.meld(bpio_input_watcher,boxes)
bpio_output_watcher = meld.meld(bpio_output_watcher,boxes)

data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_site)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_core)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_internal_input)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_input)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_output)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_input_watcher)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_output_watcher)})

