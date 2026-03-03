extends Control

## Core raid gameplay — map generation, turns, movement, loot, combat, extraction.

const MAX_TURNS := 30
const EXTRACT_WINDOW_START := 25
const EXTRACT_WINDOW_END := 30
const MAP_SIZE := 5

# Map data
var rooms: Array = []  # 2D array [x][y] of room dictionaries
var previous_pos: Vector2i = Vector2i(0, 0)
var visited_rooms: Array = []  # 2D array [x][y] of bools

# Combat state
var in_combat: bool = false
var current_enemy: Dictionary = {}

# UI references
@onready var turn_label: Label = %TurnLabel
@onready var hp_label: Label = %HPLabel
@onready var weight_label: Label = %WeightLabel
@onready var room_title: Label = %RoomTitle
@onready var room_desc: RichTextLabel = %RoomDesc
@onready var action_container: VBoxContainer = %ActionContainer
@onready var log_text: RichTextLabel = %LogText
@onready var status_label: Label = %StatusLabel
@onready var minimap_grid: GridContainer = %MinimapGrid
@onready var map_toggle_btn: Button = %MapToggleBtn
var minimap_expanded: bool = false

var event_log: Array = []


func _ready() -> void:
	_generate_map()
	# Init visited rooms grid
	visited_rooms = []
	for x in MAP_SIZE:
		var col: Array = []
		for y in MAP_SIZE:
			col.append(false)
		visited_rooms.append(col)
	visited_rooms[0][0] = true
	map_toggle_btn.pressed.connect(_toggle_minimap)
	_add_log("[color=#ffb347]RAID BEGINS. You have 30 turns. Extract or die.[/color]")
	_add_log("You drop into the zone at grid [0,0].")
	_update_ui()
	_update_minimap()
	_show_room()


func _toggle_minimap() -> void:
	minimap_expanded = !minimap_expanded
	map_toggle_btn.text = "MAP  " + ("^" if minimap_expanded else "v")
	_update_minimap()


# --- Map Generation ---

const ROOM_TYPES := ["storage", "corridor", "labs", "office", "barracks", "medbay", "armory"]
const ROOM_NAMES := {
	"storage": ["Storage Unit", "Supply Cache", "Cargo Hold"],
	"corridor": ["Dark Corridor", "Maintenance Tunnel", "Hallway"],
	"labs": ["Research Lab", "Chem Lab", "Server Room"],
	"office": ["Ransacked Office", "Command Post", "Admin Block"],
	"barracks": ["Barracks", "Guard Post", "Bunkhouse"],
	"medbay": ["Medical Bay", "Field Hospital", "Triage Room"],
	"armory": ["Armory", "Weapons Locker", "Arms Cache"],
	"extraction": ["Extraction Point", "LZ Alpha", "Evac Zone"],
}

const ROOM_DESCRIPTIONS := {
	"storage": [
		"Metal shelves line the walls, most stripped bare. The air smells of rust and old oil.",
		"Crates are stacked haphazardly. Something has been through here recently.",
		"A climate-controlled unit. The power is still running — unusual.",
	],
	"corridor": [
		"Flickering overhead lights cast long shadows. Water drips from a cracked pipe.",
		"The passage is narrow. Boot prints in the dust lead in both directions.",
		"Emergency lighting bathes everything in dull red. The silence is oppressive.",
	],
	"labs": [
		"Broken glass crunches underfoot. Monitors display corrupted data streams.",
		"Chemical smell burns your nostrils. Someone left in a hurry.",
		"Rows of workstations, most smashed. A centrifuge still hums quietly.",
	],
	"office": [
		"Papers scattered everywhere. A coffee mug still warm on the desk.",
		"Filing cabinets torn open. Whoever was here wanted something specific.",
		"Corporate logos on the wall. The safe in the corner has been forced open.",
	],
	"barracks": [
		"Bunk beds, lockers, the smell of gun oil. Standard military quarters.",
		"Personal effects scattered across unmade beds. Left in a hurry.",
		"Weapon racks line the wall — mostly empty. A few rounds on the floor.",
	],
	"medbay": [
		"Medical supplies strewn across gurneys. The antiseptic smell is strong.",
		"IV drips hang from stands, bags long empty. Blood on the floor tiles.",
		"A well-stocked medical station. Someone kept this place maintained.",
	],
	"armory": [
		"Reinforced door hangs off its hinges. Heavy-duty storage racks inside.",
		"Ammunition crates and weapon cases. Most have been cracked open.",
		"The good stuff was taken. But not everything.",
	],
	"extraction": [
		"Open ground with clear sight lines. Flares mark the evac zone.",
		"A helicopter pad. Radio static crackles from a broken transmitter.",
		"Sandbags and wire mark the extraction perimeter. This is the way out.",
	],
}

const ROOM_ABBREVIATIONS := {
	"storage": "SR",
	"corridor": "CO",
	"labs": "LA",
	"office": "OF",
	"barracks": "BK",
	"medbay": "MD",
	"armory": "AR",
	"extraction": "EX",
}

const ENEMY_TYPES := {
	"Scav": { "loot_table": ["Scrap Metal", "Bandage", "Gunpowder", "Cloth Strips", "Metal Scrap"] },
	"Armoured": { "loot_table": ["Copper Wire", "Circuit Board", "Medkit", "Gun Parts", "Rubber Seal"] },
	"Elite": { "loot_table": ["Gold Watch", "USB Drive", "Pistol", "Gun Parts", "Adhesive"] },
}
const ENEMY_NAMES_BY_TIER := {
	"Scav": ["Scav", "Raider", "Feral Dog"],
	"Armoured": ["PMC", "Armoured Guard"],
	"Elite": ["Elite Operative", "Rogue AI Drone"],
}


func _generate_map() -> void:
	rooms = []
	var extract_count := 0
	var scav_rank := GameData.get_skill_rank("scavenger")

	for x in MAP_SIZE:
		var col: Array = []
		for y in MAP_SIZE:
			var room := {}

			if x == 0 and y == 0:
				# Starting room — always safe
				room["type"] = "corridor"
				room["name"] = "Insertion Point"
				room["desc"] = "You've dropped in. The zone stretches out before you. Move carefully."
				room["loot"] = []
				room["enemies"] = []
				room["is_extract"] = false
				room["is_looted"] = true
			else:
				var is_extract := false
				# Place extract points at far corners/edges
				if extract_count < 3:
					if (x >= 3 and y >= 3) or (x == 4 and y >= 2) or (x >= 2 and y == 4):
						if randf() < 0.4 or (x == 4 and y == 4 and extract_count == 0):
							is_extract = true
							extract_count += 1

				if is_extract:
					room["type"] = "extraction"
				else:
					room["type"] = ROOM_TYPES[randi() % ROOM_TYPES.size()]

				var names_list: Array = ROOM_NAMES.get(room["type"], ["Unknown Room"])
				room["name"] = names_list[randi() % names_list.size()]

				var descs_list: Array = ROOM_DESCRIPTIONS.get(room["type"], ["An empty room."])
				room["desc"] = descs_list[randi() % descs_list.size()]

				room["loot"] = ItemDatabase.get_random_loot(room["type"], scav_rank)
				room["enemies"] = _generate_enemies(x, y)
				room["is_extract"] = is_extract
				room["is_looted"] = false

			col.append(room)
		rooms.append(col)

	# Guarantee at least 2 extract points
	if extract_count < 2:
		for _i in range(2 - extract_count):
			var ex := randi_range(3, 4)
			var ey := randi_range(3, 4)
			if rooms[ex][ey]["type"] != "extraction":
				rooms[ex][ey]["type"] = "extraction"
				rooms[ex][ey]["name"] = "Extraction Point"
				rooms[ex][ey]["desc"] = "Open ground with clear sight lines. Flares mark the evac zone."
				rooms[ex][ey]["is_extract"] = true
				rooms[ex][ey]["loot"] = ItemDatabase.get_random_loot("extraction", scav_rank)


func _generate_enemies(x: int, y: int) -> Array:
	# More enemies further from start, scaled by run count
	var distance := x + y
	var run_bonus: float = GameData.run_count * 0.1
	var enemy_chance: float = clampf(0.1 + distance * 0.08 + run_bonus, 0.0, 0.8)

	var enemies: Array = []
	var count := 0
	if randf() < enemy_chance:
		count = 1
		if distance >= 4 and randf() < 0.3 + run_bonus:
			count = 2

	for _i in count:
		# Pick tier based on distance
		var tier: String
		if distance >= 6:
			tier = "Elite"
		elif distance >= 3:
			tier = "Armoured"
		else:
			tier = "Scav"

		var names: Array = ENEMY_NAMES_BY_TIER[tier]
		# HP tuned so a 15-dmg pistol kills in 1-2 shots (Scav), 2 (Armoured), 2-3 (Elite)
		var base_hp: int
		var base_dmg: int
		match tier:
			"Scav":
				base_hp = randi_range(10, 18) + GameData.run_count * 3
				base_dmg = randi_range(5, 10) + GameData.run_count * 2
			"Armoured":
				base_hp = randi_range(22, 30) + GameData.run_count * 4
				base_dmg = randi_range(10, 18) + GameData.run_count * 2
			_: # Elite
				base_hp = randi_range(38, 55) + GameData.run_count * 5
				base_dmg = randi_range(18, 28) + GameData.run_count * 3
		enemies.append({
			"name": names[randi() % names.size()],
			"hp": base_hp,
			"max_hp": base_hp,
			"damage": base_dmg,
			"loot_table": ENEMY_TYPES[tier]["loot_table"],
		})

	return enemies


# --- UI ---

func _update_ui() -> void:
	var turn_color := "#00ff41"
	if GameData.current_turn >= EXTRACT_WINDOW_START:
		turn_color = "#ff4444"
	elif GameData.current_turn >= 20:
		turn_color = "#ffb347"
	turn_label.text = "TURN: %d / %d" % [GameData.current_turn, MAX_TURNS]

	var hp_color := "#00ff41"
	if GameData.current_hp < 30:
		hp_color = "#ff4444"
	elif GameData.current_hp < 60:
		hp_color = "#ffb347"
	hp_label.text = "HP: %d/%d" % [GameData.current_hp, GameData.max_hp]

	weight_label.text = "WT: %.1f/%.0fkg" % [GameData.current_weight, GameData.max_weight]

	var pos := GameData.player_pos
	var room: Dictionary = rooms[pos.x][pos.y]
	room_title.text = "%s [%d,%d]" % [room["name"], pos.x, pos.y]

	# Update status bar
	if GameData.current_turn >= EXTRACT_WINDOW_START and GameData.current_turn <= EXTRACT_WINDOW_END:
		status_label.text = "!! EXTRACTION WINDOW OPEN — GET OUT NOW !!"
	elif GameData.current_turn >= 20:
		status_label.text = "Extract window opens in %d turns" % (EXTRACT_WINDOW_START - GameData.current_turn)
	else:
		var armor_text := ""
		if GameData.get_armor_reduction() > 0:
			armor_text = " | Armor: -%d%%" % int(GameData.get_armor_reduction() * 100)
		status_label.text = "Grid [%d,%d] | Dmg: %d%s" % [pos.x, pos.y, GameData.get_player_damage(), armor_text]


func _update_minimap() -> void:
	for child in minimap_grid.get_children():
		child.queue_free()

	var pos := GameData.player_pos
	# Compact: small dots. Expanded: labelled squares.
	var cell_w := 36 if minimap_expanded else 18
	var cell_h := 28 if minimap_expanded else 12
	var font_size := 9 if minimap_expanded else 7

	# y=4 at top (north), y=0 at south
	for y_display in MAP_SIZE:
		var y := MAP_SIZE - 1 - y_display
		for x in MAP_SIZE:
			var cell := Label.new()
			cell.custom_minimum_size = Vector2(cell_w, cell_h)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.add_theme_font_size_override("font_size", font_size)
			cell.clip_contents = true

			var is_current := (x == pos.x and y == pos.y)
			var room: Dictionary = rooms[x][y]
			var is_extract: bool = room["is_extract"]
			var visited: bool = visited_rooms[x][y]
			var abbr: String = ROOM_ABBREVIATIONS.get(room["type"], "??")

			var bg := ColorRect.new()
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg.show_behind_parent = true

			if is_current:
				# Player position — bright green
				bg.color = Color("#00ff41")
				cell.text = abbr if minimap_expanded else ""
				cell.add_theme_color_override("font_color", Color(0, 0, 0))
			elif is_extract and not visited:
				# Unvisited extract — dim amber (always reveal so player can navigate)
				bg.color = Color("#2a1800")
				cell.text = "EX" if minimap_expanded else ""
				cell.add_theme_color_override("font_color", Color("#ffb347"))
			elif is_extract and visited:
				# Visited extract — bright amber
				bg.color = Color("#ffb347")
				cell.text = "EX" if minimap_expanded else ""
				cell.add_theme_color_override("font_color", Color(0, 0, 0))
			elif visited:
				# Visited normal room — dark green
				bg.color = Color("#1a3a1a")
				cell.text = abbr if minimap_expanded else ""
				cell.add_theme_color_override("font_color", Color("#00ff41"))
			else:
				# Unvisited, unknown — near black
				bg.color = Color(0.06, 0.06, 0.06)
				cell.text = ""

			cell.add_child(bg)
			minimap_grid.add_child(cell)


func _show_room() -> void:
	var pos := GameData.player_pos
	var room: Dictionary = rooms[pos.x][pos.y]

	# Room description
	room_desc.clear()
	room_desc.push_color(Color(0.7, 0.7, 0.7))
	room_desc.add_text(room["desc"])
	room_desc.pop()

	if room["is_extract"]:
		room_desc.newline()
		room_desc.push_color(Color(0, 1, 0.25))
		room_desc.add_text("[EXTRACTION POINT]")
		room_desc.pop()

	# Check for enemies
	if room["enemies"].size() > 0 and not in_combat:
		in_combat = true
		current_enemy = room["enemies"][0]
		_add_log("[color=#ff4444]CONTACT! %s (HP: %d, DMG: %d)[/color]" % [
			current_enemy["name"], current_enemy["hp"], current_enemy["damage"]
		])
		_show_combat_actions()
		return

	# Check for loot
	if not room["is_looted"] and room["loot"].size() > 0:
		room_desc.newline()
		room_desc.push_color(Color(1, 0.702, 0.278))
		room_desc.add_text("Items visible: %d" % room["loot"].size())
		room_desc.pop()

	_show_normal_actions()


func _clear_actions() -> void:
	for child in action_container.get_children():
		child.queue_free()


func _add_action_button(text: String, callback: Callable, color: Color = Color(0, 1, 0.25)) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(callback)
	action_container.add_child(btn)


func _show_normal_actions() -> void:
	_clear_actions()
	var pos := GameData.player_pos

	# Movement
	if pos.y < MAP_SIZE - 1:
		_add_action_button("> MOVE NORTH", _move_north)
	if pos.y > 0:
		_add_action_button("> MOVE SOUTH", _move_south)
	if pos.x < MAP_SIZE - 1:
		_add_action_button("> MOVE EAST", _move_east)
	if pos.x > 0:
		_add_action_button("> MOVE WEST", _move_west)

	# Loot
	var room: Dictionary = rooms[pos.x][pos.y]
	if not room["is_looted"] and room["loot"].size() > 0:
		_add_action_button("> LOOT ROOM", _loot_room, Color(1, 0.702, 0.278))

	# Meds in inventory
	for i in GameData.inventory.size():
		var item: Dictionary = GameData.inventory[i]
		if item.get("type") == "med":
			var btn_text := "> USE %s (HP+%d)" % [item["name"].to_upper(), item.get("heal", 0)]
			var idx := i
			_add_action_button(btn_text, func(): _use_med(idx), Color(0.3, 0.8, 1.0))

	# Hide (skip turn)
	_add_action_button("> HIDE (skip turn)", _hide, Color(0.6, 0.6, 0.6))

	# Inventory
	_add_action_button("> CHECK INVENTORY", _check_inventory, Color(0.6, 0.6, 0.6))

	# Extract
	if room["is_extract"]:
		if GameData.current_turn >= EXTRACT_WINDOW_START and GameData.current_turn <= EXTRACT_WINDOW_END:
			_add_action_button(">> EXTRACT <<", _extract, Color(0, 1, 0))
		else:
			_add_action_button("> EXTRACT (opens turn 25)", _try_extract_early, Color(0.4, 0.4, 0.4))
	elif GameData.current_turn >= EXTRACT_WINDOW_START and GameData.current_turn <= EXTRACT_WINDOW_END:
		_add_action_button("! GO TO EX ZONE TO EXTRACT", func(): _add_log("Find an amber EX zone on the map and get there!"), Color(1, 0.4, 0.1))


func _show_combat_actions() -> void:
	_clear_actions()
	_add_action_button("> ATTACK (%d dmg)" % GameData.get_player_damage(), _attack, Color(1, 0.3, 0.3))

	# Flee with dynamic chance from skills
	var flee_pct := int(GameData.get_flee_chance() * 100)
	_add_action_button("> FLEE (%d%%, costs 2 turns)" % flee_pct, _flee, Color(1, 0.702, 0.278))

	# Throwables (molotov)
	for i in GameData.inventory.size():
		var item: Dictionary = GameData.inventory[i]
		if item.get("type") == "throwable":
			var btn_text := "> THROW %s (%d dmg)" % [item["name"].to_upper(), item.get("damage", 0)]
			var idx := i
			_add_action_button(btn_text, func(): _use_throwable(idx), Color(1, 0.5, 0.0))

	# Allow med use in combat
	for i in GameData.inventory.size():
		var item: Dictionary = GameData.inventory[i]
		if item.get("type") == "med":
			var btn_text := "> USE %s (HP+%d)" % [item["name"].to_upper(), item.get("heal", 0)]
			var idx := i
			_add_action_button(btn_text, func(): _use_med_combat(idx), Color(0.3, 0.8, 1.0))


# --- Actions ---

func _advance_turn(cost: int = 1) -> void:
	GameData.current_turn += cost

	# Check if past extraction window — permadeath
	if GameData.current_turn > EXTRACT_WINDOW_END:
		_add_log("[color=#ff4444]The extraction window has closed. You are trapped.[/color]")
		_add_log("[color=#ff4444]No one is coming for you.[/color]")
		await get_tree().create_timer(1.5).timeout
		_die()
		return

	_update_ui()


func _move(direction: Vector2i, dir_name: String) -> void:
	if in_combat:
		return
	previous_pos = GameData.player_pos
	GameData.player_pos += direction
	visited_rooms[GameData.player_pos.x][GameData.player_pos.y] = true
	_advance_turn()
	_add_log("Moved %s to [%d,%d]" % [dir_name, GameData.player_pos.x, GameData.player_pos.y])
	_update_ui()
	_update_minimap()
	_show_room()


func _move_north() -> void: _move(Vector2i(0, 1), "NORTH")
func _move_south() -> void: _move(Vector2i(0, -1), "SOUTH")
func _move_east() -> void: _move(Vector2i(1, 0), "EAST")
func _move_west() -> void: _move(Vector2i(-1, 0), "WEST")


func _loot_room() -> void:
	var pos := GameData.player_pos
	var room: Dictionary = rooms[pos.x][pos.y]
	if room["is_looted"] or room["loot"].size() == 0:
		_add_log("Nothing left to loot here.")
		return

	_clear_actions()

	# Show loot items as pickup buttons
	for item in room["loot"]:
		var item_ref: Dictionary = item
		var extra := ""
		if item.get("type") == "armor":
			extra = " [-%d%%]" % int(item.get("damage_reduction", 0.0) * 100)
		elif item.get("type") == "throwable":
			extra = " [%d dmg]" % item.get("damage", 0)
		var btn_text := "> TAKE: %s (%.1fkg, %dxp)%s" % [item["name"], item["weight"], item["value"], extra]
		_add_action_button(btn_text, func(): _pick_up_item(item_ref), Color(1, 0.702, 0.278))

	_add_action_button("> DONE LOOTING", func():
		rooms[pos.x][pos.y]["is_looted"] = true
		_advance_turn()
		_add_log("Finished looting.")
		_update_ui()
		_show_room()
	, Color(0.6, 0.6, 0.6))


func _pick_up_item(item: Dictionary) -> void:
	if GameData.add_to_inventory(item):
		var extra_msg := ""
		if item.get("type") == "armor" and GameData.equipped_armor.get("name") == item.get("name"):
			extra_msg = " [EQUIPPED]"
		_add_log("[color=#ffb347]Picked up: %s%s[/color]" % [item["name"], extra_msg])
		var pos := GameData.player_pos
		var loot: Array = rooms[pos.x][pos.y]["loot"]
		for i in loot.size():
			if loot[i].get("name") == item.get("name"):
				loot.remove_at(i)
				break
		_update_ui()
		# Refresh loot display
		if loot.size() > 0:
			_loot_room()
		else:
			rooms[pos.x][pos.y]["is_looted"] = true
			_advance_turn()
			_show_room()
	else:
		_add_log("[color=#ff4444]Too heavy! Can't carry that.[/color]")


func _hide() -> void:
	_advance_turn()
	_add_log("You hold position and wait. Turn passes.")
	_update_ui()
	_show_room()


func _check_inventory() -> void:
	_clear_actions()
	if GameData.inventory.size() == 0:
		_add_log("Inventory is empty.")
	else:
		_add_log("[color=#ffb347]--- INVENTORY ---[/color]")
		for item in GameData.inventory:
			var extra := ""
			if item.get("type") == "weapon":
				extra = " [DMG:%d]" % item.get("damage", 0)
			elif item.get("type") == "med":
				extra = " [HEAL:%d]" % item.get("heal", 0)
			elif item.get("type") == "armor":
				extra = " [ARMOR: -%d%%]" % int(item.get("damage_reduction", 0.0) * 100)
			elif item.get("type") == "throwable":
				extra = " [DMG:%d]" % item.get("damage", 0)
			_add_log("  %s (%.1fkg, %dxp)%s" % [item["name"], item["weight"], item["value"], extra])
		if not GameData.equipped_weapon.is_empty():
			_add_log("[color=#00ff41]Weapon: %s[/color]" % GameData.equipped_weapon["name"])
		if not GameData.equipped_armor.is_empty():
			_add_log("[color=#4dc8ff]Armor: %s (-%d%%)[/color]" % [GameData.equipped_armor["name"], int(GameData.get_armor_reduction() * 100)])

	_add_action_button("> BACK", func():
		_update_ui()
		_show_room()
	, Color(0.6, 0.6, 0.6))


func _use_med(index: int) -> void:
	var heal := GameData.use_med(index)
	if heal > 0:
		_add_log("[color=#4dc8ff]Used medicine. Healed %d HP.[/color]" % heal)
		_advance_turn()
		_update_ui()
		_show_room()


func _use_med_combat(index: int) -> void:
	var heal := GameData.use_med(index)
	if heal > 0:
		_add_log("[color=#4dc8ff]Used medicine. Healed %d HP.[/color]" % heal)
		# Enemy gets a free hit
		_enemy_attacks()
		if GameData.current_hp <= 0:
			return
		_advance_turn()
		_update_ui()
		_show_combat_actions()


# --- Combat ---

func _drop_enemy_loot(enemy: Dictionary) -> void:
	var loot_table: Array = enemy.get("loot_table", [])
	if loot_table.is_empty():
		return
	var drop_count := randi_range(1, 2)
	var dropped: Array = []
	for _i in drop_count:
		var item_name: String = loot_table[randi() % loot_table.size()]
		if item_name in dropped:
			continue
		dropped.append(item_name)
		var item: Dictionary = ItemDatabase.get_item_by_name(item_name)
		if item.is_empty():
			continue
		if GameData.add_to_inventory(item):
			_add_log("[color=#ffb347]Looted %s from enemy[/color]" % item["name"])
		else:
			_add_log("[color=#ff4444]%s dropped but too heavy to carry[/color]" % item["name"])


func _attack() -> void:
	var roll := randf()
	var dmg := GameData.get_player_damage()
	var crit_chance := GameData.get_crit_chance()
	var miss_threshold := 0.15

	if roll < miss_threshold:
		# 15% miss
		_add_log("[color=#aaaaaa]MISS! Your attack goes wide.[/color]")
		dmg = 0
	elif roll < miss_threshold + crit_chance:
		# Crit with skill-based multiplier
		var crit_mult := GameData.get_crit_multiplier()
		dmg = int(float(dmg) * crit_mult)
		_add_log("[color=#ff00ff]CRITICAL HIT! You deal %d damage to %s![/color]" % [dmg, current_enemy["name"]])
	else:
		_add_log("You hit %s for %d damage." % [current_enemy["name"], dmg])

	current_enemy["hp"] -= dmg

	if current_enemy["hp"] <= 0:
		_add_log("[color=#00ff41]%s eliminated.[/color]" % current_enemy["name"])
		_drop_enemy_loot(current_enemy)
		# Remove enemy from room
		var pos := GameData.player_pos
		var enemies: Array = rooms[pos.x][pos.y]["enemies"]
		for i in enemies.size():
			if enemies[i] == current_enemy:
				enemies.remove_at(i)
				break
		in_combat = false
		current_enemy = {}
		_advance_turn()
		_update_ui()
		_show_room()
		return

	# Enemy attacks back
	_enemy_attacks()
	if GameData.current_hp <= 0:
		return

	_advance_turn()
	_update_ui()
	_show_combat_actions()


func _use_throwable(index: int) -> void:
	if index < 0 or index >= GameData.inventory.size():
		return
	var item: Dictionary = GameData.inventory[index]
	if item.get("type") != "throwable":
		return
	var throw_dmg: int = int(item.get("damage", 0))
	# Remove from inventory
	GameData.current_weight -= item.get("weight", 0.0)
	GameData.inventory.remove_at(index)

	_add_log("[color=#ff8800]MOLOTOV! Enemy takes %d fire damage![/color]" % throw_dmg)
	current_enemy["hp"] -= throw_dmg

	if current_enemy["hp"] <= 0:
		_add_log("[color=#00ff41]%s eliminated.[/color]" % current_enemy["name"])
		_drop_enemy_loot(current_enemy)
		var pos := GameData.player_pos
		var enemies: Array = rooms[pos.x][pos.y]["enemies"]
		for i in enemies.size():
			if enemies[i] == current_enemy:
				enemies.remove_at(i)
				break
		in_combat = false
		current_enemy = {}
		_advance_turn()
		_update_ui()
		_show_room()
		return

	# Enemy attacks back
	_enemy_attacks()
	if GameData.current_hp <= 0:
		return

	_advance_turn()
	_update_ui()
	_show_combat_actions()


func _enemy_attacks() -> void:
	var roll := randf()
	var enemy_dmg: int = current_enemy["damage"]

	if roll < 0.10:
		# 10% miss
		_add_log("[color=#aaaaaa]%s MISSES![/color]" % current_enemy["name"])
		enemy_dmg = 0
	elif roll < 0.25:
		# 15% crit (1.5x damage)
		enemy_dmg = int(enemy_dmg * 1.5)
		_add_log("[color=#ff0000]CRITICAL HIT! %s deals %d damage![/color]" % [current_enemy["name"], enemy_dmg])
	else:
		_add_log("[color=#ff4444]%s hits you for %d damage![/color]" % [current_enemy["name"], enemy_dmg])

	# Apply armor damage reduction
	if enemy_dmg > 0:
		var reduction := GameData.get_armor_reduction()
		if reduction > 0.0:
			var absorbed := int(float(enemy_dmg) * reduction)
			enemy_dmg -= absorbed
			if enemy_dmg < 1 and absorbed > 0:
				enemy_dmg = 1  # Minimum 1 damage through armor
			_add_log("[color=#aaffaa]Armor absorbed %d damage[/color]" % absorbed)

	GameData.current_hp -= enemy_dmg

	if GameData.current_hp <= 0:
		GameData.current_hp = 0
		_add_log("[color=#ff4444]YOU ARE DEAD.[/color]")
		_update_ui()
		await get_tree().create_timer(1.5).timeout
		_die()


func _flee() -> void:
	var flee_chance := GameData.get_flee_chance()
	if randf() < flee_chance:
		_add_log("[color=#ffb347]You break contact and hold position![/color]")
		# Remove enemy from room so _show_room() doesn't immediately restart combat
		var pos := GameData.player_pos
		var room_enemies: Array = rooms[pos.x][pos.y]["enemies"]
		for i in room_enemies.size():
			if room_enemies[i] == current_enemy:
				room_enemies.remove_at(i)
				break
		in_combat = false
		current_enemy = {}
		_advance_turn(2)
		_update_ui()
		_show_room()
	else:
		_add_log("[color=#ff4444]Failed to escape![/color]")
		_enemy_attacks()
		if GameData.current_hp <= 0:
			return
		_advance_turn(2)
		_update_ui()
		_show_combat_actions()


# --- Extraction ---

func _extract() -> void:
	_add_log("[color=#00ff41]EXTRACTING... You made it out.[/color]")
	var score := GameData.get_inventory_value()
	GameData.record_extraction(GameData.inventory, score)
	await get_tree().create_timer(1.0).timeout
	get_tree().change_scene_to_file("res://scenes/PostRaid.tscn")


func _try_extract_early() -> void:
	var remaining := EXTRACT_WINDOW_START - GameData.current_turn
	if remaining > 0:
		_add_log("[color=#ffb347]Extraction not available yet — %d turns remaining.[/color]" % remaining)
	else:
		_add_log("[color=#ff4444]Extraction window has closed. You are trapped.[/color]")


func _die() -> void:
	var score := GameData.get_inventory_value()
	GameData.record_death(score)
	get_tree().change_scene_to_file("res://scenes/PostRaid.tscn")


# --- Event Log ---

func _add_log(message: String) -> void:
	event_log.push_front(message)
	if event_log.size() > 5:
		event_log.resize(5)

	log_text.clear()
	for entry in event_log:
		log_text.append_text(entry)
		log_text.newline()
