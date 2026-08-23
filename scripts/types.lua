---@alias checkStatus "?"|"y"|"n"
---@alias LuaPlayerIndex uint32
---@alias coreID uint64
---@alias quality_name string
---@alias qualityCounts table<quality_name,number>
---@alias itemList table<data.ItemName,qualityCounts>

---@class planPlaces
---@field inventory table<uint64,table<defines.inventory,LuaInventory>>
---@field grids table<uint64,LuaEquipmentGrid>

---@class planMemory
---@field places planPlaces
---@field beggining ItemStackDefinition[]
---@field ending ItemStackDefinition[]

---@class coreEntities
---@field core LuaEntity
---@field building LuaEntity
---@field input LuaEntity
---@field output LuaEntity

---@class coreInventories
---@field blueprint LuaInventory
---@field building LuaInventory
---@field input LuaInventory
---@field output LuaInventory

---@class coreAuxiliaries
---@field surface LuaSurface
---@field surface_index uint32
---@field properties table<LuaSurfacePropertyPrototype,double>
---@field rendering LuaRenderObject
---@field render_name string
---@field position MapPosition
---@field force LuaForce
---@field section LuaLogisticSection
---@field statistics LuaFlowStatistics
---@field progress_bars LuaGuiElement[] The progress bar

---@class coreState
---@field status "off"|"booting"|"standby"|"on"
---@field check number Check number
---@field checks checkStatus[] Status of each check
---@field lock boolean Lock destroy/die
---@field sim_lock? "idle"|"build_ghosts"|"build_entities"|"retry_entities"|"initialize_inventories"|"initialize_logs"|"busy"|"epilog" What stage the surface is on
---@field progress double How much has the surface ran

---@class coreSimulation
---@field surface? LuaSurface
---@field force? LuaForce
---@field size? TilePosition 
---@field input_watcher? LuaInventory
---@field output_watcher? LuaInventory
---@field ghosts? LuaEntity[] The ghosts we build
---@field plan_memory? planMemory

---@class coreData
---@field pollution number The pollution we registered during the simulation
---@field cost ItemStackDefinition[] What items we used to build this core. To give back to the player.
---@field input ItemStackDefinition[] What will be spawned in the surface, once.
---@field output ItemStackDefinition[] What will be spawned in the active entity every cycle.
---@field input_list itemList We use this to compare each point in time when the surface is being simulated.
---@field output_list itemList We use this for the GUI
---@field history itemList[] Lists of items at different times of the surface

---@class coreDict
---@field ids table<string,coreID> All of the unit_numbers of the entities this core has
---@field ent coreEntities The LuaEntities of the compound
---@field inv coreInventories The LuaInventories of the entities and the scripts 
---@field aux coreAuxiliaries References to useful stuff about the core like the force, the signals, the stats, etc.
---@field state coreState This yields detailed information about the core state.
---@field sim coreSimulation This holds stuff we need during the booting of the core.
---@field data coreData This stores the data we get from the booting process.

---@class dictionaryDict
---@field core table<coreID,coreDict>
---@field player table<LuaPlayerIndex,coreID>

---@alias queueDict table<MapTick, coreID[]>