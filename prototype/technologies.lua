data:extend(
{
  {
    type = "technology",
    name = "blueprint-io",
    effects = 
    {
      { type = "unlock-recipe", recipe = "bpio-core" }
    },
    icons = 
    {
      { icon = "__blueprint_io__/thumbnail.png", icon_size = 64 }
    },
    prerequisites = { "automation-3", "robotics" },
    unit = 
    {
      count = 500,
      ingredients = 
      {
        { "automation-science-pack", 1 },
        { "logistic-science-pack", 1 },
        { "chemical-science-pack", 1 },
        { "production-science-pack", 1 },
        { "utility-science-pack", 1 }
      },
      time = 30
    }
  }
}
)