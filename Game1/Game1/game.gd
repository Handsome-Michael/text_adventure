extends Control

const Response = preload("res://input/response.tscn")
const InputResponse = preload("res://input/InputResponse.tscn")

@export var max_lines_remembered := 30

@onready var command_processor = %CommandProcessor
@onready var history_rows = %HistoryRows
@onready var scroll = %Scroll
@onready var scrollbar = scroll.get_v_scroll_bar()
@onready var room_manager = %RoomManager
@onready var player = $Player
@onready var save_load_manager = %SaveLoadManager

func _ready() -> void:
	scrollbar.changed.connect(handle_scrollbar_changed)
	
	create_response("Welcome to the retro text adventure! You can type 'help' to see available commands.")

	var starting_room_response = command_processor.initialize(room_manager.get_child(0), player)
	create_response(starting_room_response)
	
	# Initialize SaveLoadManager
	save_load_manager.command_processor = command_processor

func handle_scrollbar_changed():
	scroll.scroll_vertical = scrollbar.max_value

func _on_input_text_submitted(new_text: String) -> void:
	if new_text.is_empty():
		return

	var input_response = InputResponse.instantiate()
	var response = command_processor.process_command(new_text)
	input_response.set_text(new_text, response)
	add_response_to_game(input_response)

	# Handle save and load commands
	if new_text.to_lower() == "save":
		var save_result = save_load_manager.save_game()
		create_response(save_result)
	elif new_text.to_lower() == "load":
		var load_result = save_load_manager.load_game()
		create_response(load_result)
		if load_result == "Game loaded successfully.":
			update_game_state()

func create_response(response_text: String):
	var response = Response.instantiate()
	response.text = response_text
	add_response_to_game(response)

func add_response_to_game(response: Control):
	history_rows.add_child(response)
	delete_history_beyond_limit()

func delete_history_beyond_limit():
	if history_rows.get_child_count() > max_lines_remembered:
		var rows_to_forget = history_rows.get_child_count() - max_lines_remembered
		for i in range(rows_to_forget):
			history_rows.get_child(i).queue_free()

func update_game_state():
	# Update UI after loading a game
	create_response(command_processor.current_room.get_full_description())
	# Add any other necessary updates here
