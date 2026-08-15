data:extend(
{
  {
    type = "recipe",
    name = "bpio-site",
    enabled = false,
    ingredients = 
    {
      { type = "item", name = "processing-unit", amount = 500 }
    },
    results = 
    {
      { type = "item", name = "bpio-site", amount = 1 }
    }
  },
  {
    type = "recipe",
    name = "bpio-blueprintable-input",
    enabled = false,
    ingredients = 
    {
      { type = "item", name = "iron-plate", amount = 5 },
      { type = "item", name = "iron-gear-wheel", amount = 5 },
      { type = "item", name = "steel-plate", amount = 5 }
    },
    results = 
    {
      { type = "item", name = "bpio-blueprintable-input", amount = 1 }
    }
  },
  {
    type = "recipe",
    name = "bpio-blueprintable-output",
    enabled = false,
    ingredients = 
    {
      { type = "item", name = "iron-plate", amount = 5 },
      { type = "item", name = "iron-gear-wheel", amount = 5 },
      { type = "item", name = "steel-plate", amount = 5 }
    },
    results = 
    {
      { type = "item", name = "bpio-blueprintable-output", amount = 1 }
    }
  }
}
)