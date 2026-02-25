extends Control

## Core raid gameplay — map generation, turns, movement, loot, combat, extraction.

const MAX_TURNS := 30
const EXTRACT_WINDOW_START := 25
const EXTRACT_WINDOW_END := 30
const MAP_SIZE := 5

# Map data
var rooms: Array = []  # 2D array [x][y] of room dictionaries
var previous_pos: Vector2i = Vector2i(0, 0)

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

var event_log: Array = []


func _ready() -> void:
	_generate_map()
	_add_log("[color=#ffb347]RAID BEGINS. You have 30 turns. Extract or die.[/color]")
	_add_log("You drop into the zone at grid [0,0].")
	_update_ui()
	_show_room()


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

const ENEMY_NAMES := ["Scav", "Raider", "PMC", "Rogue AI Drone", "Feral Dog"]


func _generate_map() -> void:
	rooms = []
	var extract_count := 0

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

				room["loot"] = ItemDatabase.get_random_loot(room["type"])
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
				rooms[ex][ey]["loot"] = ItemDatabase.get_random_loot("extraction")


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
		var base_hp := randi_range(20, 40) + GameData.run_count * 5
		var base_dmg := randi_range(5, 15) + GameData.run_count * 2
		enemies.append({
			"name": ENEMY_NAMES[randi() % ENEMY_NAMES.size()],
			"hp": base_hp,
			"max_hp": base_hp,
			"damage": base_dmg,
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
	hp_label.text = "HP: %d" % GameData.current_hp

	weight_label.text = "WT: %.1f/%dkg" % [GameData.current_weight, GameData.max_weight]

	var pos := GameData.player_pos
	var room: Dictionary = rooms[pos.x][pos.y]
	room_title.text = "%s [%d,%d]" % [room["name"], pos.x, pos.y]

	# Update status bar
	if GameData.current_turn >= EXTRACT_WINDOW_START and GameData.current_turn <= EXTRACT_WINDOW_END:
		status_label.text = "!! EXTRACTION WINDOW OPEN — GET OUT NOW !!"
	elif GameData.current_turn >= 20:
		status_label.text = "Extract window opens in %d turns" % (EXTRACT_WINDOW_START - GameData.current_turn)
	else:
		status_label.text = "Grid [%d,%d] | Dmg: %d" % [pos.x, pos.y, GameData.get_player_damage()]


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
			_add_action_button("> EXTRACT (locked)", _try_extract_early, Color(0.4, 0.4, 0.4))


func _show_combat_actions() -> void:
	_clear_actions()
	_add_action_button("> ATTACK (%d dmg)" % GameData.get_player_damage(), _attack, Color(1, 0.3, 0.3))
	_add_action_button("> FLEE (60%%, costs 2 turns)", _flee, Color(1, 0.702, 0.278))

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
	_advance_turn()
	_add_log("Moved %s to [%d,%d]" % [dir_name, GameData.player_pos.x, GameData.player_pos.y])
	_update_ui()
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
		var item_ref := item
		var btn_text := "> TAKE: %s (%.1fkg, %dxp)" % [item["name"], item["weight"], item["value"]]
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
		_add_log("[color=#ffb347]Picked up: %s[/color]" % item["name"])
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
			_add_log("  %s (%.1fkg, %dxp)%s" % [item["name"], item["weight"], item["value"], extra])
		if not GameData.equipped_weapon.is_empty():
			_add_log("[color=#00ff41]Equipped: %s[/color]" % GameData.equipped_weapon["name"])

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

func _attack() -> void:
	var dmg := GameData.get_player_damage()
	current_enemy["hp"] -= dmg
	_add_log("You hit %s for %d damage." % [current_enemy["name"], dmg])

	if current_enemy["hp"] <= 0:
		_add_log("[color=#00ff41]%s eliminated.[/color]" % current_enemy["name"])
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


func _enemy_attacks() -> void:
	var enemy_dmg: int = current_enemy["damage"]
	GameData.current_hp -= enemy_dmg
	_add_log("[color=#ff4444]%s hits you for %d damage![/color]" % [current_enemy["name"], enemy_dmg])

	if GameData.current_hp <= 0:
		GameData.current_hp = 0
		_add_log("[color=#ff4444]YOU ARE DEAD.[/color]")
		_update_ui()
		await get_tree().create_timer(1.5).timeout
		_die()


func _flee() -> void:
	if randf() < 0.6:
		_add_log("[color=#ffb347]You disengage and fall back![/color]")
		in_combat = false
		current_enemy = {}
		GameData.player_pos = previous_pos
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
