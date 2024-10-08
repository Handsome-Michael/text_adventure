extends Node

const CombatManager = preload("res://CombatManager.gd")

var current_room = null
var player = null
var replay_manager = null
var combat_manager = null

func _ready():
	combat_manager = CombatManager.new()

func initialize(starting_room, player_ref, replay_manager_ref) -> String:
	if starting_room == null or player_ref == null or replay_manager_ref == null:
		push_error("Starting room, player, or replay manager cannot be null")
		return "Initialization error"
	player = player_ref
	replay_manager = replay_manager_ref
	current_room = null  # Reset current room
	return change_room(starting_room)

func process_command(input: String) -> String:
	var words = input.split(" ", false)
	if words.size() == 0:
		return "Error: no words were parsed."
		
	var first_word = words[0].to_lower()
	var second_word = ""
	var third_word = ""
	
	if words.size() > 1:
		second_word = words[1].to_lower()
	if words.size() > 2:
		third_word = words[2].to_lower()
		
	if combat_manager.is_combat_active():
		return combat_manager.process_action(first_word)
		
	match first_word:
		"go":
			return go(second_word)
		"take":
			return take(second_word)
		"drop":
			return drop(second_word)
		"inventory":
			return inventory()
		"use":
			return use(second_word, third_word)
		"talk":
			return talk(second_word)
		"give":
			return give(second_word, third_word)
		"put":
			return put(second_word, third_word)
		"attack", "defend", "escape":
			if combat_manager.is_combat_active():
				return combat_manager.process_action(first_word)
			else:
				return "There's no enemy to fight!"
		"equip":
			return equip(second_word)
		"status":
			return status()
		"help":
			return help()
		"save":
			return save_game()
		"load":
			return load_game()
		_:
			return "Unrecognized command- please try again."

func save_game() -> String:
	if replay_manager == null:
		push_error("Replay manager is not initialized")
		return "Save failed"
	replay_manager.save_game()
	return "Game saved successfully."

func load_game() -> String:
	if replay_manager == null:
		push_error("Replay manager is not initialized")
		return "Load failed"
	replay_manager.load_game()
	return "Game loaded successfully."

func go(second_word: String) -> String:
	if second_word == "":
		return "Go where?"
		
	if current_room.exits.has(second_word):
		var exit = current_room.exits[second_word]
		if exit.is_passable():
			return change_room(exit.get_other_room(current_room))
		else:
			return exit.get_lock_description()
	else:
		return "There is no exit in that direction."

func take(second_word: String) -> String:
	if second_word == "":
		return "Take what?"
	
	for item in current_room.items:
		if second_word.to_lower() == item.item_name.to_lower():
			current_room.remove_item(item)
			player.take_item(item)
			return "You took the " + item.item_name + "."
	
	return "There is no " + second_word + " here."

func drop(second_word: String) -> String:
	if second_word == "":
		return "Drop what?"
	
	for item in player.inventory:
		if second_word.to_lower() == item.item_name.to_lower():
			player.drop_item(item)
			current_room.add_item(item)
			return "You dropped the " + item.item_name + "."
	
	return "You don't have that item."

func inventory() -> String:
	return player.get_inventory_list()

func use(second_word: String, third_word: String) -> String:
	if second_word == "":
		return "Use what?"
	
	for item in player.inventory:
		if second_word.to_lower() == item.item_name.to_lower():
			match item.item_type:
				Types.ItemTypes.KEY:
					return use_key(item, third_word)
				Types.ItemTypes.POTION:
					return use_potion(item)
				_:
					return "You can't use that item."
	
	return "You don't have that item."

func use_key(key: Item, direction: String) -> String:
	if direction == "":
		return "Use " + key.item_name + " where?"
	
	if current_room.exits.has(direction):
		var exit = current_room.exits[direction]
		if exit.is_locked and exit == key.unlocks:
			exit.unlock()
			player.drop_item(key)
			return "You unlocked the " + exit.lock_name + "."
		elif not exit.is_locked:
			return "That exit is already unlocked."
		else:
			return "That key doesn't fit this lock."
	else:
		return "There is no exit in that direction."

func use_potion(potion: Item) -> String:
	var heal_amount = player.use_potion(potion)
	return "You used the " + potion.item_name + " and healed for " + str(heal_amount) + " health."

func talk(second_word: String) -> String:
	if second_word == "":
		return "Talk to whom?"
	
	for npc in current_room.npcs:
		if second_word.to_lower() == npc.npc_name.to_lower():
			if npc.has_received_quest_item:
				return npc.post_quest_dialog
			else:
				return npc.initial_dialog
	
	return "There is no " + second_word + " here."

func give(second_word: String, third_word: String) -> String:
	if second_word == "" or third_word == "":
		return "Give what to whom?"
	
	var item_to_give = null
	for item in player.inventory:
		if second_word.to_lower() == item.item_name.to_lower():
			item_to_give = item
			break
	
	if item_to_give == null:
		return "You don't have that item."
	
	for npc in current_room.npcs:
		if third_word.to_lower() == npc.npc_name.to_lower():
			if npc.quest_item == item_to_give:
				return complete_quest(npc, item_to_give)
			else:
				return npc.npc_name + " doesn't want that item."
	
	return "There is no " + third_word + " here."

func complete_quest(npc: NPC, item: Item) -> String:
	npc.has_received_quest_item = true
	player.drop_item(item)
	var result = "You give the %s to %s." % [item.item_name, npc.npc_name]
	
	if npc.quest_reward != null:
		result += " " + npc.quest_reward.apply_rewards(player, current_room)
	
	return result

func put(second_word: String, third_word: String) -> String:
	if second_word == "" or third_word == "":
		return "Put what where?"
	
	match third_word:
		"down":
			return drop(second_word)
		_:
			return "You can't put things there."

func equip(second_word: String) -> String:
	if second_word == "":
		return "Equip what?"
	
	for item in player.inventory:
		if second_word.to_lower() == item.item_name.to_lower():
			if item.item_type == Types.ItemTypes.WEAPON:
				return player.equip_weapon(item)
			else:
				return "You can't equip that."
	
	return "You don't have that item."

func status() -> String:
	var status_string = "Health: " + str(player.health) + "/" + str(player.max_health) + "\n"
	status_string += "Equipped weapon: " + (player.equipped_weapon.item_name if player.equipped_weapon else "None") + "\n"
	if combat_manager.is_combat_active():
		status_string += "Current enemy: " + combat_manager.enemy.enemy_name + " (Health: " + str(combat_manager.enemy.health) + ")"
	return status_string

func help() -> String:
	return "You can use these commands:\n" + \
		   "go [location]\n" + \
		   "take [item]\n" + \
		   "drop [item]\n" + \
		   "use [item] (on [target])\n" + \
		   "talk [npc]\n" + \
		   "give [item] (to [npc])\n" + \
		   "put [item] [place]\n" + \
		   "attack\n" + \
		   "defend\n" + \
		   "equip [weapon]\n" + \
		   "status\n" + \
		   "inventory\n" + \
		   "help\n" + \
		   "save\n" + \
		   "load"

func change_room(new_room: GameRoom) -> String:
	if new_room == null:
		push_error("New room cannot be null")
		return "Change room failed"
	
	var previous_room = current_room
	current_room = new_room
	
	# Check for enemies in the new room
	if new_room.has_enemy():
		var enemy = new_room.get_enemy()
		combat_manager.start_combat(player, enemy, previous_room)
		return new_room.get_full_description() + "\n\nWarning: Combat has started with " + enemy.enemy_name + "!\n" + combat_manager.get_combat_status()
	else:
		combat_manager.change_state(combat_manager.CombatState.INACTIVE)
	
	return new_room.get_full_description()


func get_save_data() -> Dictionary:
	return {
		"current_room": current_room.room_name,
		"player": player.get_save_data(),
		"combat_manager": combat_manager.get_save_data()
	}

func load_save_data(data: Dictionary, room_manager: Node):
	current_room = room_manager.get_node(data["current_room"])
	player.load_save_data(data["player"])
	combat_manager.load_save_data(data["combat_manager"], room_manager)
