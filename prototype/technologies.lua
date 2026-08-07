data:extend(
{
  {
    type = "technology",
    name = "blueprint-io",
    effects = 
    {
      { type = "unlock-recipe", recipe = "bpio-core" },
      { type = "unlock-recipe", recipe = "bpio-input-watcher" },
      { type = "unlock-recipe", recipe = "bpio-output-watcher" }
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