data:extend({
  {
    type = "item-subgroup",
    name = "bpio",
    group = "production",
    order = "blueprint-io"
  },
  {
    type = "item",
    name = "bpio-site",
    icons = {{icon="__blueprint_io__/thumbnail.png",icon_size = 64, scale = 4/10 }},
    subgroup = "bpio",
    order = "bpio-site",
    place_result = "bpio-site",
    stack_size = 50
  },
  {
    type = "item",
    name = "bpio-blueprintable-input",
    icons = {{icon="__blueprint_io_graphics__/icons/requester-warehouse.png",icon_size = 64}},
    subgroup = "bpio",
    order = "bpio-blueprintable-input",
    place_result = "bpio-blueprintable-input",
    stack_size = 50
  },
  {
    type = "item",
    name = "bpio-blueprintable-output",
    icons = {{icon="__blueprint_io_graphics__/icons/passive-provider-warehouse.png",icon_size = 64}},
    subgroup = "bpio",
    order = "bpio-blueprintable-output",
    place_result = "bpio-blueprintable-output",
    stack_size = 50
  }
})

