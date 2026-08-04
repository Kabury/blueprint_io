
local meld = require("meld")
local created_eff =
{
    type = "direct",
    action_delivery = {
        type = "instant",
        target_effects = {
            {type = "script", effect_id = "bpio-built-event"}
        }
    }
}


local bpio_core = {name="bpio-core",created_effect=created_eff,inventory_size=0,picture={layers={[1]={filename="__blueprint_io__/graphics/icons/steel-chest.png",size=64,tint={r=0.45,g=0.3,b=0.45}}}}}


data:extend({meld.meld(table.deepcopy(data.raw["container"]["steel-chest"]),bpio_core)})


