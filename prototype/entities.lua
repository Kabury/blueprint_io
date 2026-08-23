
local meld = require("meld")
local pfix = "__blueprint_io__/graphics/"

local height = 127
local width = 156
local scale = 8/10


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
  collision_box={{-6, -6}, {6, 6}},
  icons={{icon="__blueprint_io__/thumbnail.png",icon_size=64,scale=scale}},
  picture=
  {
    layers=
    {
      [1]={filename="__blueprint_io__/thumbnail.png",height=64,width=64,scale=6}
    }
  }
}

data:extend({meld.meld(table.deepcopy(data.raw["simple-entity-with-owner"]["simple-entity-with-owner"]),bpio_site)})



local bpio_core =
{
  name="bpio-core",
  minable={ mining_time = 3, result="bpio-site" },
  selection_box={{-6, -6}, {5, 5}},
  collision_box={{-6, -6}, {5, 5}},
  placeable_by = {count=1, item="bpio-site"},
  icons={{icon="__blueprint_io__/thumbnail.png",icon_size = 64,scale=0.4}},
  flags=meld.append({"not-rotatable","not-blueprintable"}),
  corpse = "buffer-chest-remnants", 
  circuit_wire_connection_points=
  {
    {
      shadow={red = util.by_pixel(128.25,  154.25), green = util.by_pixel(128.25,  154.25),}, 
      wire={red = util.by_pixel(128.25,  154.25), green = util.by_pixel(128.25,  154.25),}
    },
    { shadow = {}, wire = {} },
    { shadow = {}, wire = {} },
    { shadow = {}, wire = {} }
  },
  activity_led_light = meld.delete(),
  activity_led_sprites = meld.delete(),
  sprites = meld.overwrite({sheets ={{filename="__core__/graphics/empty.png",height=1,width=1,scale=scale}}})
}

data:extend({meld.meld(table.deepcopy(data.raw["constant-combinator"]["constant-combinator"]),bpio_core)})


local circuit_connector = circuit_connector_definitions.create_single(
  universal_connector_template,
  { variation = 10, main_offset = util.by_pixel( -0.625,  166.25), shadow_offset = util.by_pixel( -0.625,  166.25), show_shadow = true })
local building_connector = circuit_connector_definitions.create_single(
  universal_connector_template,
  { variation = 10, main_offset = util.by_pixel( 111.25, -8.25), shadow_offset = util.by_pixel( 111.25, -8.25), show_shadow = true })


local special_box = 
{
  name="_",
  inventory_type="with_custom_stack_size",
  inventory_size=5,
  inventory_properties={stack_size_multiplier = 100, with_bar = true},
  minable = { mining_time = 3 },
  circuit_connector = {circuit_connector},
  icons={{icon="__core__/graphics/empty.png",icon_size=1}},
  picture=
  {
    layers=
    {
      {filename="__core__/graphics/empty.png",height=1,width=1,scale=scale},
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
  selection_box={{-5, -0.5}, {5, 0.5}},
  collision_box={{-4.8, -0.3}, {4.8, 0.3}},
  circuit_connector = {building_connector},
  corpse = "storage-chest-remnants"
})
core.building.flags = meld.append({"no-automated-item-removal","not-blueprintable"})
core.building.corpse=meld.delete()
core.building.picture.layers[2]=meld.delete()

meld.meld(core.input,
{
  name="bpio-core-input",
  selection_box={{-0.5, -6}, {0.5, 6}},
  collision_box={{-0.3, -5.8}, {0.3, 5.8}},
  corpse = "requester-chest-remnants"
})
core.input.flags = meld.append({"no-automated-item-removal","not-blueprintable"})
core.input.corpse=meld.delete()
core.input.picture.layers[2]=meld.delete()

meld.meld(core.output,
{
  name="bpio-core-output",
  selection_box={{-0.5, -6}, {0.5, 6}},
  collision_box={{-0.3, -5.8}, {0.3, 5.8}},
  corpse = "passive-provider-chest-remnants"
})
core.output.flags = meld.append({"no-automated-item-insertion","not-blueprintable"})
core.output.corpse=meld.delete()
core.output.picture.layers[2]=meld.delete()

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
  minable={ mining_time = 1, result="bpio-blueprintable-input"},
  corpse = "requester-chest-remnants", 
  flags={"no-automated-item-insertion"},
  selection_box={{-3.5, -3.5}, {3.5, 3.5}},
  collision_box={{-3.3, -3.3}, {3.3, 3.3}},
  icons={{icon="__blueprint_io_graphics__/icons/requester-warehouse.png", icon_size = 64}},
  picture={layers={{filename="__blueprint_io_graphics__/entities/requester-warehouse.png",height=512,width=512,scale=0.55}}}
})
blueprintable.input.flags = meld.append({"no-automated-item-insertion"})

meld.meld(blueprintable.output,
{
  name="bpio-blueprintable-output",
  minable={ mining_time = 1, result="bpio-blueprintable-output"},
  corpse = "passive-provider-chest-remnants", 
  flags={"no-automated-item-removal"},
  selection_box={{-3.5, -3.5}, {3.5, 3.5}},
  collision_box={{-3.3, -3.3}, {3.3, 3.3}},
  icons={{icon="__blueprint_io_graphics__/icons/passive-provider-warehouse.png", icon_size = 64}},
  picture={layers={{filename="__blueprint_io_graphics__/entities/passive-provider-warehouse.png",height=512,width=512,scale=0.55}}}
})
blueprintable.output.flags = meld.append({"no-automated-item-removal"})

data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),blueprintable.input)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),blueprintable.output)})