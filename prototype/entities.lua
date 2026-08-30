
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
  corpse = "cargo-landing-pad-remnants", 
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
  universal_connector_template --[[@as lualib.connector_sprite_template]],
  { variation = 10, main_offset = util.by_pixel( -0.625,  166.25), shadow_offset = util.by_pixel( -0.625,  166.25), show_shadow = true })
local building_connector = circuit_connector_definitions.create_single(
  universal_connector_template --[[@as lualib.connector_sprite_template]],
  { variation = 10, main_offset = util.by_pixel( 111.25, -8.25), shadow_offset = util.by_pixel( 111.25, -8.25), show_shadow = true })


local special_box = 
{
  name="_",
  inventory_type="with_custom_stack_size",
  inventory_size=7,
  inventory_properties={stack_size_multiplier = 1000},
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
core.building.inventory_size=49
core.input = table.deepcopy(special_box)
core.output = table.deepcopy(special_box)

meld.meld(core.building,
{
  name="bpio-core-building",
  selection_box={{-5, -0.5}, {5, 0.5}},
  collision_box={{-4.8, -0.3}, {4.8, 0.3}},
  circuit_connector = {building_connector}
})
core.building.flags = meld.append({"no-automated-item-removal","not-blueprintable"})
core.building.corpse=meld.delete()
core.building.picture.layers[2]=meld.delete() ---@diagnostic disable-line: inject-field

meld.meld(core.input,
{
  name="bpio-core-input",
  selection_box={{-0.5, -6}, {0.5, 6}},
  collision_box={{-0.3, -5.8}, {0.3, 5.8}}
})
core.input.flags = meld.append({"no-automated-item-removal","not-blueprintable"})
core.input.corpse=meld.delete()
core.input.picture.layers[2]=meld.delete() ---@diagnostic disable-line: inject-field

meld.meld(core.output,
{
  name="bpio-core-output",
  selection_box={{-0.5, -6}, {0.5, 6}},
  collision_box={{-0.3, -5.8}, {0.3, 5.8}}
})
core.output.flags = meld.append({"no-automated-item-insertion","not-blueprintable"})
core.output.corpse=meld.delete()
core.output.picture.layers[2]=meld.delete() ---@diagnostic disable-line: inject-field

data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),core.building)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),core.input)})
data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),core.output)})

if (data.raw.container["bpio-core-building"].minable and data.raw.container["bpio-core-input"].minable and data.raw.container["bpio-core-output"].minable) then
  data.raw.container["bpio-core-building"].minable.result=nil
  data.raw.container["bpio-core-input"].minable.result=nil
  data.raw.container["bpio-core-output"].minable.result=nil
end

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

local collider_scale = 0.85
local collider_sizes = {0.8,1.8,2.8,3.8,4.8,5.8,6.8,7.8,8.8,9.8}

local colors = settings.startup["bpio-colors"].value
local tints
if colors then 
  tints = {{r=0.6,g=0.6,b=0.6},{r=229,g=45,b=229},{r=137,g=45,b=229},{r=45,g=45,b=229},{r=45,g=229,b=229},{r=45,g=229,b=137},{r=137,g=229,b=45},{r=229,g=229,b=45},{r=229,g=137,b=45},{r=229,g=45,b=45}}
else
  tints = {{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6},{r=0.6,g=0.6,b=0.6}}
end

data:extend({
  {
    type = "simple-entity",
    name = "10-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[10]*2+0.4)/6,width=227,height=226,tint=tints[10]},
    selection_box={{-collider_sizes[10], -collider_sizes[10]}, {collider_sizes[10], collider_sizes[10]}},
    collision_box={{-collider_sizes[10], -collider_sizes[10]}, {collider_sizes[10], collider_sizes[10]}},
  },
  {
    type = "simple-entity",
    name = "9-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[9]*2+0.4)/6,width=227,height=226,tint=tints[9]},
    selection_box={{-collider_sizes[9], -collider_sizes[9]}, {collider_sizes[9], collider_sizes[9]}},
    collision_box={{-collider_sizes[9], -collider_sizes[9]}, {collider_sizes[9], collider_sizes[9]}},
  },  
  {
    type = "simple-entity",
    name = "8-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[8]*2+0.4)/6,width=227,height=226,tint=tints[8]},
    selection_box={{-collider_sizes[8], -collider_sizes[8]}, {collider_sizes[8], collider_sizes[8]}},
    collision_box={{-collider_sizes[8], -collider_sizes[8]}, {collider_sizes[8], collider_sizes[8]}},
  },  
  {
    type = "simple-entity",
    name = "7-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[7]*2+0.4)/6,width=227,height=226,tint=tints[7]},
    selection_box={{-collider_sizes[7], -collider_sizes[7]}, {collider_sizes[7], collider_sizes[7]}},
    collision_box={{-collider_sizes[7], -collider_sizes[7]}, {collider_sizes[7], collider_sizes[7]}},
  },
  {
    type = "simple-entity",
    name = "6-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[6]*2+0.4)/6,width=227,height=226,tint=tints[6]},
    selection_box={{-collider_sizes[6], -collider_sizes[6]}, {collider_sizes[6], collider_sizes[6]}},
    collision_box={{-collider_sizes[6], -collider_sizes[6]}, {collider_sizes[6], collider_sizes[6]}},
  },
  {
    type = "simple-entity",
    name = "5-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[5]*2+0.4)/6,width=227,height=226,tint=tints[5]},
    selection_box={{-collider_sizes[5], -collider_sizes[5]}, {collider_sizes[5], collider_sizes[5]}},
    collision_box={{-collider_sizes[5], -collider_sizes[5]}, {collider_sizes[5], collider_sizes[5]}},
  },
  {
    type = "simple-entity",
    name = "4-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[4]*2+0.4)/6,width=227,height=226,tint=tints[4]},
    selection_box={{-collider_sizes[4], -collider_sizes[4]}, {collider_sizes[4], collider_sizes[4]}},
    collision_box={{-collider_sizes[4], -collider_sizes[4]}, {collider_sizes[4], collider_sizes[4]}},
  },
  {
    type = "simple-entity",
    name = "3-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[3]*2+0.4)/6,width=227,height=226,tint=tints[3]},
    selection_box={{-collider_sizes[3], -collider_sizes[3]}, {collider_sizes[3], collider_sizes[3]}},
    collision_box={{-collider_sizes[3], -collider_sizes[3]}, {collider_sizes[3], collider_sizes[3]}},
  },
  {
    type = "simple-entity",
    name = "2-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[2]*2+0.4)/6,width=227,height=226,tint=tints[2]},
    selection_box={{-collider_sizes[2], -collider_sizes[2]}, {collider_sizes[2], collider_sizes[2]}},
    collision_box={{-collider_sizes[2], -collider_sizes[2]}, {collider_sizes[2], collider_sizes[2]}},
  },
  {
    type = "simple-entity",
    name = "1-collider",
    pictures = {filename="__blueprint_io_graphics__/entities/exotic-space-ind-matrix-low.png",variation_count = 1,scale=collider_scale*(collider_sizes[1]*2+0.4)/6,width=227,height=226,tint=tints[1]},
    selection_box={{-collider_sizes[1], -collider_sizes[1]}, {collider_sizes[1], collider_sizes[1]}},
    collision_box={{-collider_sizes[1], -collider_sizes[1]}, {collider_sizes[1], collider_sizes[1]}},
  },
})

data:extend({
  {
    type = "land-mine",
    name = "bpio-land-mine",
    trigger_radius = 0.1,
    dying_trigger_effect = {type = "script", effect_id = "bpio-wire-event"},
    circuit_connector = {
      points = {
        shadow = {
          green = { 0.1, 0.3 },
          red = { -0.1, 0.3 }
        },
        wire = {
          green = { 0.1, 0.3 },
          red = { -0.1, 0.3 }
        }
      },
    },
    circuit_wire_max_distance = 9
  }
})