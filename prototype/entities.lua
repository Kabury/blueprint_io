
local meld = require("meld")
local pfix = "__blueprint_io__/graphics/"

local height = 127
local width = 156
local scale = 48/32
local icon_size = 32

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

local bpio_site =
{
  name="bpio-site",
  minable = meld.delete(),
  created_effect=created_eff,
  collision_box={{-7.3, -7.3}, {7.3, 2.3}},
  icons={{icon=pfix.."icons/core_market.png",icon_size=icon_size,scale=scale}},
  picture=
  {
    layers=
    {
      [1]={filename=pfix.."entity/core_market.png",height=height,width=width,scale=scale,shift={1.5,0.25}},
      [3]={filename=pfix.."entity/building_market.png",height=height,width=width,scale=scale,shift={1.5,0.25-5}},
      [4]={filename=pfix.."entity/input_market.png",height=height,width=width,scale=scale,shift={1.5-5,0.25}},
      [5]={filename=pfix.."entity/output_market.png",height=height,width=width,scale=scale,shift={1.5+5,0.25}}
    }
  }
}

data:extend({meld.meld(table.deepcopy(data.raw["simple-entity-with-owner"]["simple-entity-with-owner"]),bpio_site)})



local bpio_core =
{
  name="bpio-core",
  minable={ mining_time = 5, result="bpio-site" },
  selection_box={{-2.3, -2.3}, {2.3, 2.3}},
  collision_box={{-2.3, -2.3}, {2.3, 2.3}},
  placeable_by = {count=1, item="bpio-site"},
  icons={{icon=pfix.."icons/core_market.png",icon_size=icon_size,scale=scale}},
  flags=meld.append({"not-rotatable","not-blueprintable"}),
  corpse = "buffer-chest-remnants", 
  circuit_wire_connection_points=
  {
    {
      shadow={red = util.by_pixel(24.5, 64.5), green = util.by_pixel(24.5, 64.5),}, 
      wire={red = util.by_pixel(24.5, 64.5), green = util.by_pixel(24.5, 64.5),}
    },
    { shadow = {}, wire = {} },
    { shadow = {}, wire = {} },
    { shadow = {}, wire = {} }
  },
  activity_led_light = meld.delete(),
  activity_led_sprites = meld.delete(),
  sprites = meld.overwrite({sheets ={{filename=pfix.."entity/core_market.png",frames=1,height=height,width=width,scale=scale,shift={1.5,0.25}}}})
}

data:extend({meld.meld(table.deepcopy(data.raw["constant-combinator"]["constant-combinator"]),bpio_core)})


local circuit_connector = circuit_connector_definitions.create_single(
  universal_connector_template,
  { variation = 26, main_offset = util.by_pixel( 24.5,  64.5), shadow_offset = util.by_pixel( 24.5,  64.5), show_shadow = true })

local special_box = 
{
  name="_",
  inventory_type="with_custom_stack_size",
  inventory_size=5,
  inventory_properties={stack_size_multiplier = 100, with_bar = true},
  minable = { mining_time = 5 },
  selection_box={{-2.3, -2.3}, {2.3, 2.3}},
  collision_box={{-2.3, -2.3}, {2.3, 2.3}},
  circuit_connector = {circuit_connector},
  icons={{icon="_",icon_size=icon_size,scale=scale}},
  picture=
  {
    layers=
    {
      {filename="_",height=height,width=width,scale=scale,shift={1.5,0.25}}
    }
  }
}

local core = {}
core.building = table.deepcopy(special_box)
core.building.inventory_size=47
core.input = table.deepcopy(special_box)
core.output = table.deepcopy(special_box)

meld.meld(core.building,
{
  name="bpio-core-building",
  placeable_by = {count=1, item="bpio-site"},
  corpse = "storage-chest-remnants", 
  icons={{icon=pfix.."icons/building_market.png"}},
  picture={layers={{filename=pfix.."entity/building_market.png"}}}
})
core.building.flags = meld.append({"no-automated-item-removal","not-blueprintable"})

meld.meld(core.input,
{
  name="bpio-core-input",
  placeable_by = {count=1, item="bpio-site"},
  corpse = "requester-chest-remnants", 
  icons={{icon=pfix.."icons/input_market.png"}},
  picture={layers={{filename=pfix.."entity/input_market.png"}}}
})
core.input.flags = meld.append({"no-automated-item-removal","not-blueprintable"})

meld.meld(core.output,
{
  name="bpio-core-output",
  placeable_by = {count=1, item="bpio-site"},
  corpse = "passive-provider-chest-remnants", 
  icons={{icon=pfix.."icons/output_market.png"}},
  picture={layers={{filename=pfix.."entity/output_market.png"}}}
})
core.output.flags = meld.append({"no-automated-item-insertion","not-blueprintable"})

data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),core.building)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),core.input)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),core.output)})

data.raw.container["bpio-core-building"].minable.result=nil
data.raw.container["bpio-core-input"].minable.result=nil
data.raw.container["bpio-core-output"].minable.result=nil

local blueprintable = {}
blueprintable.input = table.deepcopy(special_box)
blueprintable.output = table.deepcopy(special_box)

meld.meld(blueprintable.input,
{
  name="bpio-blueprintable-input",
  minable={result="bpio-blueprintable-input"},
  corpse = "requester-chest-remnants", 
  flags={"no-automated-item-insertion"},
  icons={{icon=pfix.."icons/input_market.png"}},
  picture={layers={{filename=pfix.."entity/input_market.png"}}}
})
blueprintable.input.flags = meld.append({"no-automated-item-insertion"})

meld.meld(blueprintable.output,
{
  name="bpio-blueprintable-output",
  minable={result="bpio-blueprintable-output"},
  corpse = "passive-provider-chest-remnants", 
  flags={"no-automated-item-removal"},
  icons={{icon=pfix.."icons/output_market.png"}},
  picture={layers={{filename=pfix.."entity/output_market.png"}}}
})
blueprintable.output.flags = meld.append({"no-automated-item-removal"})

data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),blueprintable.input)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),blueprintable.output)})