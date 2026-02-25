class_name ItemDatabase

## Static item definitions and loot generation.

# Item types: "weapon", "med", "component", "valuable"

const ITEMS := {
	# --- Weapons ---
	"pistol": {
		"name": "Pistol",
		"type": "weapon",
		"weight": 3.0,
		"damage": 15,
		"value": 50,
		"desc": "9mm sidearm. Reliable.",
	},
	"shotgun": {
		"name": "Shotgun",
		"type": "weapon",
		"weight": 5.0,
		"damage": 30,
		"value": 80,
		"desc": "Pump-action. Devastating at close range.",
	},
	"combat_knife": {
		"name": "Combat Knife",
		"type": "weapon",
		"weight": 1.0,
		"damage": 10,
		"value": 30,
		"desc": "Military-grade blade. Silent.",
	},
	"smg": {
		"name": "SMG",
		"type": "weapon",
		"weight": 3.5,
		"damage": 20,
		"value": 65,
		"desc": "Compact submachine gun. Fast.",
	},

	# --- Meds ---
	"bandage": {
		"name": "Bandage",
		"type": "med",
		"weight": 0.5,
		"heal": 20,
		"value": 20,
		"desc": "Basic wound dressing.",
	},
	"medkit": {
		"name": "Medkit",
		"type": "med",
		"weight": 1.0,
		"heal": 50,
		"value": 60,
		"desc": "Field medical kit. Thorough treatment.",
	},
	"painkillers": {
		"name": "Painkillers",
		"type": "med",
		"weight": 0.2,
		"heal": 10,
		"value": 15,
		"desc": "Take the edge off.",
	},

	# --- Components ---
	"copper_wire": {
		"name": "Copper Wire",
		"type": "component",
		"weight": 0.2,
		"value": 15,
		"desc": "Spool of electrical wire.",
	},
	"circuit_board": {
		"name": "Circuit Board",
		"type": "component",
		"weight": 0.3,
		"value": 40,
		"desc": "Intact PCB. Useful for crafting.",
	},
	"gunpowder": {
		"name": "Gunpowder",
		"type": "component",
		"weight": 0.5,
		"value": 25,
		"desc": "Smokeless powder. Handle with care.",
	},
	"scrap_metal": {
		"name": "Scrap Metal",
		"type": "component",
		"weight": 1.0,
		"value": 10,
		"desc": "Bent sheet metal. Salvageable.",
	},
	"duct_tape": {
		"name": "Duct Tape",
		"type": "component",
		"weight": 0.3,
		"value": 12,
		"desc": "Fixes everything. Almost.",
	},

	# --- Valuables ---
	"gold_watch": {
		"name": "Gold Watch",
		"type": "valuable",
		"weight": 0.1,
		"value": 100,
		"desc": "Luxury timepiece. Worth a fortune.",
	},
	"usb_drive": {
		"name": "USB Drive",
		"type": "valuable",
		"weight": 0.1,
		"value": 75,
		"desc": "Encrypted data. Someone wants this.",
	},
	"laptop": {
		"name": "Laptop",
		"type": "valuable",
		"weight": 2.0,
		"value": 150,
		"desc": "Military-grade laptop. Heavy but valuable.",
	},
	"dog_tags": {
		"name": "Dog Tags",
		"type": "valuable",
		"weight": 0.05,
		"value": 35,
		"desc": "Someone didn't make it out.",
	},
}

# Loot tables by room type — maps room type to array of item keys
const LOOT_TABLES := {
	"storage": ["scrap_metal", "duct_tape", "copper_wire", "bandage", "combat_knife", "gunpowder"],
	"corridor": ["bandage", "painkillers", "scrap_metal", "dog_tags"],
	"labs": ["circuit_board", "usb_drive", "laptop", "medkit", "copper_wire", "smg"],
	"office": ["usb_drive", "laptop", "gold_watch", "circuit_board", "pistol", "dog_tags"],
	"barracks": ["pistol", "shotgun", "smg", "combat_knife", "medkit", "bandage", "gunpowder", "dog_tags"],
	"medbay": ["medkit", "bandage", "painkillers", "circuit_board"],
	"armory": ["pistol", "shotgun", "smg", "combat_knife", "gunpowder"],
	"extraction": ["bandage", "painkillers", "scrap_metal"],
	"default": ["scrap_metal", "bandage", "copper_wire", "dog_tags", "painkillers"],
}


static func get_item(item_key: String) -> Dictionary:
	if ITEMS.has(item_key):
		var item: Dictionary = ITEMS[item_key].duplicate()
		item["key"] = item_key
		return item
	return {}


static func get_random_loot(room_type: String) -> Array:
	var table_key := room_type.to_lower()
	if not LOOT_TABLES.has(table_key):
		table_key = "default"
	var table: Array = LOOT_TABLES[table_key]

	var item_count := randi_range(0, 3)
	var result: Array = []
	var used_keys: Array = []

	for i in item_count:
		if table.is_empty():
			break
		var attempts := 0
		while attempts < 10:
			var key: String = table[randi() % table.size()]
			if key not in used_keys:
				used_keys.append(key)
				result.append(get_item(key))
				break
			attempts += 1

	return result


static func get_all_item_keys() -> Array:
	return ITEMS.keys()


static func break_down_item(item: Dictionary) -> Array:
	## Break an item into components. Returns array of component items.
	var value: int = item.get("value", 10)
	var components: Array = []

	# Every item breaks into scrap + maybe something else
	components.append(get_item("scrap_metal"))
	if value >= 40:
		components.append(get_item("copper_wire"))
	if value >= 80:
		components.append(get_item("circuit_board"))

	return components
