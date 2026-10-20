extends Node
## GameState — all persistent player progress plus the core rules
## (inventory, coins, XP, discovery, plant growth, requests, milestones).
## The World reads/writes plot data here so saving is just serializing this node.

const DAY_START := 360        ## 6:00 AM, in game minutes
const DAY_END := 1560         ## 2:00 AM next day -> you pass out (gently)
const SEASON_LENGTH := 10     ## days per season
const SECONDS_PER_MINUTE := 0.45
const START_COINS := 500

## World regions on a 3x3 grid of 40x30-tile blocks.
const REGIONS := {
	"mountains":      {"gx": 0, "gy": 0, "cost": 2500,  "level": 5,  "forage": "rocks",   "desc": "Hardy alpine flowers, herbs and buried fossils."},
	"crystal_biome":  {"gx": 1, "gy": 0, "cost": 9000,  "level": 9,  "forage": "crystal", "desc": "Crystal plants that bloom like jewels."},
	"ancient_ruins":  {"gx": 2, "gy": 0, "cost": 15000, "level": 11, "forage": "rubble",  "desc": "Exotic jungle plants and long-lost ancient seeds."},
	"forest":         {"gx": 0, "gy": 1, "cost": 800,   "level": 3,  "forage": "bush",    "desc": "Herbs, berry bushes and fruit tree saplings."},
	"home":           {"gx": 1, "gy": 1, "cost": 0,     "level": 1,  "forage": "sparkle", "desc": "Your very own garden."},
	"village":        {"gx": 2, "gy": 1, "cost": 0,     "level": 1,  "forage": "sparkle", "desc": "Shops, requests and friendly neighbors."},
	"mushroom_caves": {"gx": 0, "gy": 2, "cost": 1500,  "level": 4,  "forage": "mushroom","desc": "Dozens of strange and glowing mushrooms."},
	"flower_fields":  {"gx": 1, "gy": 2, "cost": 350,   "level": 2,  "forage": "flowers", "desc": "Meadows bursting with wild flower seeds."},
	"fairy_garden":   {"gx": 2, "gy": 2, "cost": 5000,  "level": 7,  "forage": "fairy",   "desc": "Mythical plants tended by tiny fairies."},
}

## Garden expansions bought at the Land Office.
const EXPANSIONS := [
	{"id": "plot_1", "name": "Garden Plot Expansion I", "cost": 400, "level": 2, "desc": "Widen your farm field."},
	{"id": "greenhouse", "name": "Greenhouse", "cost": 1500, "level": 3, "desc": "Grow ANY plant in ANY season."},
	{"id": "plot_2", "name": "Garden Plot Expansion II", "cost": 1200, "level": 4, "desc": "Lengthen your farm field."},
	{"id": "seed_station", "name": "Rare Seed Station", "cost": 2500, "level": 5, "desc": "Produces a random rare seed every 3 days."},
	{"id": "patio", "name": "Decorative Patio & Fountain", "cost": 1800, "level": 5, "desc": "A stone patio that makes the garden prettier."},
	{"id": "plant_lab", "name": "Plant Laboratory", "cost": 4000, "level": 6, "desc": "Extract seeds from crops, with mutation chances."},
	{"id": "plot_3", "name": "Garden Plot Expansion III", "cost": 3500, "level": 7, "desc": "A huge farm field."},
	{"id": "magic_garden", "name": "Magical Garden", "cost": 8000, "level": 9, "desc": "Enchanted soil: double growth for rare plants, more mutations."},
	{"id": "plot_4", "name": "Garden Plot Expansion IV", "cost": 9000, "level": 10, "desc": "The ultimate farm field."},
]

const MILESTONES := [
	[10, 300, ""], [25, 600, "trophy_bronze"], [50, 1200, "fountain_small"], [75, 2000, "trophy_silver"],
	[100, 3000, "wishing_well"], [150, 5000, "trophy_gold"], [200, 8000, "fountain_grand"],
	[250, 12000, "trophy_platinum"], [300, 16000, "crystal_lamp"], [350, 25000, "trophy_rainbow"],
]

const NPCS := ["Rosie", "Mr. Fern", "Clover", "Hazel", "Old Moss", "Juniper", "Pip"]
const WEATHER_TABLE := [
	{"sunny": 50, "cloudy": 20, "rain": 30},
	{"sunny": 60, "cloudy": 15, "rain": 15, "windy": 10},
	{"sunny": 35, "cloudy": 20, "rain": 20, "windy": 25},
	{"snow": 45, "cloudy": 30, "sunny": 25},
]

# ---------------------------------------------------------------- STATE
var coins := START_COINS
var xp := 0
var level := 1
var day := 1
var season := 0
var year := 1
var total_days := 1
var minutes := float(DAY_START)
var weather := "sunny"
var water := 15
var tools := {}
var inventory := {}
var discovered := {}          ## id -> 1 (seed seen) / 2 (collected)
var plots := {}               ## "x,y" -> {plant, age, watered, fert, zone}
var unlocked := ["home", "village"]
var expansions := []
var decor := {}               ## "x,y" -> decor id
var requests := []
var forage := {}              ## "x,y" -> {region, kind}
var milestones_claimed := []
var completed_cats := []
var station_days := 0
var festival_claimed := []
var stats := {"harvests": 0, "planted": 0, "forage": 0, "requests": 0, "earned": 0, "mutations": 0}
var player_pos := Vector2.ZERO
var hotbar_key := ""
var playing := false
var _time_accum := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func reset_new_game() -> void:
	coins = START_COINS
	xp = 0
	level = 1
	day = 1
	season = 0
	year = 1
	total_days = 1
	minutes = DAY_START
	weather = "sunny"
	tools = {}
	for t in ItemDB.TOOL_ORDER:
		tools[t] = 1
	water = capacity()
	inventory = {}
	discovered = {}
	plots = {}
	unlocked = ["home", "village"]
	expansions = []
	decor = {}
	requests = []
	forage = {}
	milestones_claimed = []
	completed_cats = []
	station_days = 0
	festival_claimed = []
	stats = {"harvests": 0, "planted": 0, "forage": 0, "requests": 0, "earned": 0, "mutations": 0}
	player_pos = Vector2.ZERO
	hotbar_key = ""
	# Starter kit
	add_item("seed:turnip", 8, false)
	add_item("seed:tulip", 5, false)
	add_item("seed:radish", 4, false)
	add_item("compost", 4, false)
	for t in ItemDB.TOOL_ORDER:
		discover("tool_%s_1" % t, false)
	discover("compost", false)
	generate_requests()


# ================================================================= TIME
func _process(delta: float) -> void:
	if not playing or get_tree().paused:
		return
	_time_accum += delta
	while _time_accum >= SECONDS_PER_MINUTE:
		_time_accum -= SECONDS_PER_MINUTE
		minutes += 1
		if int(minutes) % 10 == 0:
			Events.time_tick.emit(int(minutes))


func clock_text() -> String:
	var m := int(minutes) % 1440
	var h := m / 60
	var mm := (m % 60) / 10 * 10
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, ampm]


func date_text() -> String:
	return "%s %d, Year %d" % [ItemDB.SEASON_NAMES[season], day, year]


func daylight() -> float:
	## 0 = darkest night, 1 = full day
	var m := minutes
	if m < 420: return lerp(0.55, 1.0, clamp((m - 360) / 60.0, 0.0, 1.0))
	if m < 1080: return 1.0
	if m < 1260: return lerp(1.0, 0.0, (m - 1080) / 180.0)
	return 0.0


func is_festival() -> bool:
	return day == ItemDB.FESTIVAL_DAY


# ================================================================= COINS / XP
func add_coins(n: int) -> void:
	coins += n
	if n > 0:
		stats["earned"] += n
	Events.coins_changed.emit(coins)


func spend(n: int) -> bool:
	if coins < n:
		Events.toast.emit("Not enough coins!", Color("ff8a7a"))
		Audio.play("error")
		return false
	coins -= n
	Events.coins_changed.emit(coins)
	return true


func xp_needed(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	return int(90 * pow(lv, 1.45))


func add_xp(n: int) -> void:
	xp += n
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		Events.level_up.emit(level)
		Events.toast.emit("Garden Level %d!  New unlocks available." % level, Color("ffd45a"))
	Events.xp_changed.emit(level, xp, xp_needed())


# ================================================================= INVENTORY
func count(key: String) -> int:
	return int(inventory.get(key, 0))


func add_item(key: String, n: int = 1, notify: bool = true) -> void:
	if n <= 0:
		return
	inventory[key] = count(key) + n
	if ItemDB.is_seed(key):
		seen(key.substr(5))
	elif not key.begins_with("tool_"):
		discover(key, notify)
	if hotbar_key == "" and is_hotbar_item(key):
		hotbar_key = key
	Events.inventory_changed.emit()


func remove_item(key: String, n: int = 1) -> bool:
	if count(key) < n:
		return false
	inventory[key] = count(key) - n
	if inventory[key] <= 0:
		inventory.erase(key)
		if hotbar_key == key:
			var hb := hotbar_items()
			hotbar_key = hb[0] if hb.size() > 0 else ""
	Events.inventory_changed.emit()
	return true


func is_hotbar_item(key: String) -> bool:
	return ItemDB.is_seed(key) or ItemDB.is_fertilizer(key) or ItemDB.is_decor(key)


func hotbar_items() -> Array:
	var seeds := []
	var ferts := []
	var decs := []
	for k in inventory.keys():
		if ItemDB.is_seed(k):
			seeds.append(k)
		elif ItemDB.is_fertilizer(k):
			ferts.append(k)
		elif ItemDB.is_decor(k):
			decs.append(k)
	var byname := func(a, b): return ItemDB.display_name(a) < ItemDB.display_name(b)
	seeds.sort_custom(byname)
	ferts.sort_custom(byname)
	decs.sort_custom(byname)
	return seeds + ferts + decs


func cycle_hotbar(dir: int) -> void:
	var hb := hotbar_items()
	if hb.is_empty():
		hotbar_key = ""
	else:
		var i := hb.find(hotbar_key)
		i = wrapi(i + dir, 0, hb.size()) if i >= 0 else 0
		hotbar_key = hb[i]
	Events.hotbar_changed.emit()


# ================================================================= DISCOVERY
func discover(id: String, notify: bool = true) -> void:
	if not ItemDB.items.has(id):
		return
	if int(discovered.get(id, 0)) >= 2:
		return
	discovered[id] = 2
	if notify:
		var r := ItemDB.rarity_of(id)
		add_xp(ItemDB.DISCOVER_XP[r])
		Events.item_discovered.emit(id)
	_check_milestones()


func seen(plant_id: String) -> void:
	if int(discovered.get(plant_id, 0)) == 0:
		discovered[plant_id] = 1
		Events.seed_seen.emit(plant_id)


func collected_count() -> int:
	var n := 0
	for k in discovered:
		if int(discovered[k]) >= 2:
			n += 1
	return n


func cat_progress(cat: String) -> Vector2i:
	var ids := ItemDB.book_ids(cat)
	var n := 0
	for id in ids:
		if int(discovered.get(id, 0)) >= 2:
			n += 1
	return Vector2i(n, ids.size())


func _check_milestones() -> void:
	var total := collected_count()
	for m in MILESTONES:
		var need: int = m[0]
		if total >= need and not (need in milestones_claimed):
			milestones_claimed.append(need)
			add_coins(m[1])
			var txt := "Collection milestone: %d discoveries!  +%d coins" % [need, m[1]]
			if String(m[2]) != "":
				inventory[m[2]] = count(m[2]) + 1
				discover(m[2], false)
				txt += " + " + ItemDB.items[m[2]]["name"]
			Events.milestone_reached.emit(txt)
	for tab in ItemDB.BOOK_TABS:
		var cat: String = tab[0]
		if cat in completed_cats:
			continue
		var p := cat_progress(cat)
		if p.x >= p.y and p.y > 0:
			completed_cats.append(cat)
			add_coins(1000 + p.y * 50)
			inventory["gardener_statue"] = count("gardener_statue") + 1
			discover("gardener_statue", false)
			Events.milestone_reached.emit("Category complete: %s!  +%d coins & Master Gardener Statue" % [tab[1], 1000 + p.y * 50])


# ================================================================= TOOLS
func capacity() -> int:
	return ItemDB.WATER_CAPACITY[int(tools.get("watering_can", 1)) - 1]


func tool_level(t: String) -> int:
	return int(tools.get(t, 1))


func upgrade_tool(t: String) -> bool:
	var lv := tool_level(t)
	if lv >= 5:
		return false
	var cost: int = ItemDB.TOOL_COSTS[lv]
	var req: int = ItemDB.TOOL_LEVEL_REQ[lv]
	if level < req:
		Events.toast.emit("Requires Garden Level %d" % req, Color("ff8a7a"))
		return false
	if not spend(cost):
		return false
	tools[t] = lv + 1
	discover("tool_%s_%d" % [t, lv + 1])
	if t == "watering_can":
		water = capacity()
		Events.water_changed.emit(water, capacity())
	Events.tool_upgraded.emit(t, lv + 1)
	return true


## Offsets (forward, sideways) affected by a tool at a given level.
func tool_pattern(lv: int) -> Array:
	match lv:
		1: return [Vector2i(0, 0)]
		2: return [Vector2i(0, 0), Vector2i(1, 0)]
		3: return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		4:
			var a := []
			for f in 3:
				for s in [-1, 0, 1]:
					a.append(Vector2i(f, s))
			return a
		_:
			var b := []
			for f in 4:
				for s in [-1, 0, 1]:
					b.append(Vector2i(f, s))
			return b


# ================================================================= UNLOCKS
func can_unlock_region(r: String) -> String:
	var d: Dictionary = REGIONS[r]
	if r in unlocked:
		return "Already unlocked"
	if level < int(d["level"]):
		return "Requires Garden Level %d" % d["level"]
	if coins < int(d["cost"]):
		return "Costs %d coins" % d["cost"]
	return ""


func unlock_region(r: String) -> bool:
	var why := can_unlock_region(r)
	if why != "":
		Events.toast.emit(why, Color("ff8a7a"))
		return false
	spend(int(REGIONS[r]["cost"]))
	unlocked.append(r)
	add_xp(80)
	Events.toast.emit("Unlocked %s!" % ItemDB.REGION_NAMES[r], Color("9ff58a"))
	Events.world_changed.emit()
	return true


func expansion_def(id: String) -> Dictionary:
	for e in EXPANSIONS:
		if e["id"] == id:
			return e
	return {}


func buy_expansion(id: String) -> bool:
	var e := expansion_def(id)
	if e.is_empty() or id in expansions:
		return false
	if level < int(e["level"]):
		Events.toast.emit("Requires Garden Level %d" % e["level"], Color("ff8a7a"))
		return false
	if not spend(int(e["cost"])):
		return false
	expansions.append(id)
	add_xp(60)
	Events.toast.emit("Built: %s!" % e["name"], Color("9ff58a"))
	Events.world_changed.emit()
	return true


func has_exp(id: String) -> bool:
	return id in expansions


# ================================================================= GROWTH
func plot_stage(p: Dictionary) -> int:
	if p.get("plant", "") == "":
		return -1
	var it: Dictionary = ItemDB.items[p["plant"]]
	var d: int = it["days"]
	var age: int = p["age"]
	if age >= d:
		return 4
	if age <= 0:
		return 0
	return clampi(1 + int(float(age) / d * 3.0), 1, 3)


## Why a plant can't grow right now ("" means it can).
func growth_block(p: Dictionary) -> String:
	var it: Dictionary = ItemDB.items[p["plant"]]
	var zone: String = p.get("zone", "farm")
	if it["needs"] != "" and p.get("fert", "") != it["needs"]:
		return "Needs " + ItemDB.items[it["needs"]]["name"]
	if zone == "farm" and not (season in it["seasons"]):
		return "Out of season (try the Greenhouse)"
	return ""


func new_day() -> Dictionary:
	## Called when the player sleeps. Returns a summary for the wake-up screen.
	var grew := 0
	var ready_count := 0
	for key in plots:
		var p: Dictionary = plots[key]
		if p.get("plant", "") != "":
			var it: Dictionary = ItemDB.items[p["plant"]]
			if p.get("watered", false) and growth_block(p) == "":
				var g := 1
				var f: String = p.get("fert", "")
				if f == "speed_gro":
					g = 2
				elif f == "compost" and rng.randf() < 0.25:
					g = 2
				if p.get("zone", "") == "magic" and int(it["rarity"]) >= 2:
					g *= 2
				var before := plot_stage(p)
				p["age"] = min(int(p["age"]) + g, int(it["days"]))
				grew += 1
				if plot_stage(p) == 4 and before != 4:
					ready_count += 1
		p["watered"] = false
	# Advance the calendar
	day += 1
	total_days += 1
	var season_changed := false
	if day > SEASON_LENGTH:
		day = 1
		season += 1
		season_changed = true
		if season > 3:
			season = 0
			year += 1
	minutes = DAY_START
	weather = _roll_weather()
	if weather == "rain":
		for key in plots:
			if plots[key].get("zone", "farm") == "farm":
				plots[key]["watered"] = true
	if has_exp("seed_station"):
		station_days += 1
	generate_requests()
	Events.day_started.emit()
	Events.weather_changed.emit(weather)
	if season_changed:
		Events.season_changed.emit(season)
	return {"grew": grew, "ready": ready_count}


func _roll_weather() -> String:
	var table: Dictionary = WEATHER_TABLE[season]
	var total := 0
	for k in table:
		total += int(table[k])
	var r := rng.randi_range(0, total - 1)
	for k in table:
		r -= int(table[k])
		if r < 0:
			return k
	return "sunny"


# ================================================================= REQUESTS
func request_pool() -> Array:
	## Things the player can realistically grow right now.
	var pool := []
	for id in ItemDB.plant_ids:
		var it: Dictionary = ItemDB.items[id]
		if it["cat"] == "seasonal":
			continue
		var known := int(discovered.get(id, 0)) > 0
		var shop_ok: bool = it["shop"] and (season in it["seasons"])
		if (known or shop_ok) and int(it["rarity"]) <= 3:
			if season in it["seasons"] or has_exp("greenhouse"):
				pool.append(id)
	return pool


func generate_requests() -> void:
	# Keep unfinished requests for one extra day, then refresh.
	var keep := []
	for r in requests:
		if not r.get("done", false) and int(r.get("days", 0)) < 1:
			r["days"] = int(r.get("days", 0)) + 1
			keep.append(r)
	requests = keep
	var pool := request_pool()
	if pool.is_empty():
		return
	var used := {}
	for r in requests:
		used[r["item"]] = true
	var tries := 0
	while requests.size() < 3 and tries < 40:
		tries += 1
		var id: String = pool[rng.randi_range(0, pool.size() - 1)]
		if used.has(id):
			continue
		used[id] = true
		var it: Dictionary = ItemDB.items[id]
		var r: int = it["rarity"]
		var qty: int = [rng.randi_range(3, 6), rng.randi_range(2, 4), rng.randi_range(1, 2), 1, 1][r]
		var reward := int(int(it["value"]) * qty * 1.7) + 20
		var bonus := ""
		if rng.randf() < 0.55:
			bonus = _random_reward_seed(r + 1)
		requests.append({"npc": NPCS[rng.randi_range(0, NPCS.size() - 1)], "item": id, "qty": qty,
			"coins": reward, "bonus": bonus, "done": false, "days": 0})
	Events.requests_changed.emit()


func _random_reward_seed(min_rarity: int) -> String:
	var cands := []
	for id in ItemDB.plant_ids:
		var it: Dictionary = ItemDB.items[id]
		if it["cat"] == "seasonal":
			continue
		if int(it["rarity"]) >= clampi(min_rarity, 1, 3) and int(it["rarity"]) <= 3:
			cands.append("seed:" + id)
	if cands.is_empty():
		return ""
	return cands[rng.randi_range(0, cands.size() - 1)]


func deliver_request(i: int) -> bool:
	if i < 0 or i >= requests.size():
		return false
	var r: Dictionary = requests[i]
	if r["done"] or count(r["item"]) < int(r["qty"]):
		return false
	remove_item(r["item"], int(r["qty"]))
	r["done"] = true
	add_coins(int(r["coins"]))
	add_xp(25 + 10 * ItemDB.rarity_of(r["item"]))
	stats["requests"] += 1
	var txt := "%s thanks you! +%d coins" % [r["npc"], r["coins"]]
	if r["bonus"] != "":
		add_item(r["bonus"], 1)
		txt += " + " + ItemDB.display_name(r["bonus"])
	Events.toast.emit(txt, Color("ffd45a"))
	Events.requests_changed.emit()
	return true


# ================================================================= LOOT
func roll_loot(table: Array, luck: float = 0.0) -> String:
	var total := 0.0
	var adj := []
	for e in table:
		var w: float = e[1]
		if ItemDB.rarity_of(e[0]) >= 2:
			w *= (1.0 + luck)
		adj.append([e[0], w])
		total += w
	var r := rng.randf() * total
	for e in adj:
		r -= e[1]
		if r <= 0:
			return e[0]
	return adj[adj.size() - 1][0] if adj.size() > 0 else ""


func station_ready() -> bool:
	return has_exp("seed_station") and station_days >= 3


func collect_station() -> String:
	if not station_ready():
		return ""
	station_days = 0
	var s := _random_reward_seed(2)
	add_item(s, 1)
	return s


# ================================================================= SAVE
func to_dict() -> Dictionary:
	return {
		"version": 1, "coins": coins, "xp": xp, "level": level, "day": day, "season": season,
		"year": year, "total_days": total_days, "minutes": minutes, "weather": weather,
		"water": water, "tools": tools, "inventory": inventory, "discovered": discovered,
		"plots": plots, "unlocked": unlocked, "expansions": expansions, "decor": decor,
		"requests": requests, "forage": forage, "milestones": milestones_claimed,
		"completed_cats": completed_cats, "station_days": station_days, "stats": stats, "festival_claimed": festival_claimed,
		"px": player_pos.x, "py": player_pos.y, "hotbar": hotbar_key,
	}


func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", START_COINS))
	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	day = int(d.get("day", 1))
	season = int(d.get("season", 0))
	year = int(d.get("year", 1))
	total_days = int(d.get("total_days", 1))
	minutes = float(d.get("minutes", DAY_START))
	weather = String(d.get("weather", "sunny"))
	water = int(d.get("water", 15))
	tools = {}
	var t: Dictionary = d.get("tools", {})
	for k in ItemDB.TOOL_ORDER:
		tools[k] = int(t.get(k, 1))
	inventory = {}
	var inv: Dictionary = d.get("inventory", {})
	for k in inv:
		if ItemDB.has_item(k):
			inventory[k] = int(inv[k])
	discovered = {}
	var disc: Dictionary = d.get("discovered", {})
	for k in disc:
		discovered[k] = int(disc[k])
	plots = {}
	var pl: Dictionary = d.get("plots", {})
	for k in pl:
		var p: Dictionary = pl[k]
		if p.get("plant", "") != "" and not ItemDB.items.has(p["plant"]):
			p["plant"] = ""
		p["age"] = int(p.get("age", 0))
		plots[k] = p
	unlocked = Array(d.get("unlocked", ["home", "village"]))
	expansions = Array(d.get("expansions", []))
	decor = d.get("decor", {})
	requests = Array(d.get("requests", []))
	for r in requests:
		r["qty"] = int(r["qty"])
		r["coins"] = int(r["coins"])
	forage = d.get("forage", {})
	milestones_claimed = []
	for m in d.get("milestones", []):
		milestones_claimed.append(int(m))
	completed_cats = Array(d.get("completed_cats", []))
	station_days = int(d.get("station_days", 0))
	festival_claimed = Array(d.get("festival_claimed", []))
	var st: Dictionary = d.get("stats", {})
	for k in stats:
		stats[k] = int(st.get(k, 0))
	player_pos = Vector2(float(d.get("px", 0)), float(d.get("py", 0)))
	hotbar_key = String(d.get("hotbar", ""))
