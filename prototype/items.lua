local pfix = "__blueprint_io__/graphics/"

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
    icons = {{icon=pfix.."icons/core_market.png",icon_size = 32}},
    subgroup = "bpio",
    order = "bpio-site",
    place_result = "bpio-site",
    stack_size = 50
  },
  {
    type = "item",
    name = "bpio-blueprintable-input",
    icons = {{icon=pfix.."icons/input_market.png",icon_size = 32}},
    subgroup = "bpio",
    order = "bpio-blueprintable-input",
    place_result = "bpio-blueprintable-input",
    stack_size = 50
  },
  {
    type = "item",
    name = "bpio-blueprintable-output",
    icons = {{icon=pfix.."icons/output_market.png",icon_size = 32}},
    subgroup = "bpio",
    order = "bpio-blueprintable-output",
    place_result = "bpio-blueprintable-output",
    stack_size = 50
  }
})

