extends Node
## Events: a global signal bus so systems stay decoupled.
## Gameplay code emits; UI and world listen.

signal coins_changed(amount: int)
signal xp_changed(level: int, xp: int, needed: int)
signal level_up(level: int)
signal inventory_changed
signal item_discovered(id: String)        ## brand-new Collection Book entry
signal seed_seen(id: String)              ## first time a plant's seed is found
signal toast(text: String, color: Color)
signal time_tick(minutes: int)
signal day_started
signal season_changed(season: int)
signal weather_changed(weather: String)
signal world_changed                       ## unlocks/expansions -> rebuild world
signal tool_upgraded(tool: String, level: int)
signal requests_changed
signal milestone_reached(text: String)
signal open_panel(panel: String, data: Variant)
signal water_changed(amount: int, capacity: int)
signal hotbar_changed
signal region_entered(region: String)
signal discovery_popup(key: String, title: String)
