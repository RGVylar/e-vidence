extends Node

## Save Game System for E-vidence
## 
## Manages save files in user://saves/ directory with JSON format.
## Each save contains:
## - metadata: player name, dates, current case, version
## - game_state: GameState variables, inventory, current case/thread  
## - db_state: DB state for case progress
##
## Usage:
## - SaveGame.create_new_save(name) -> Creates new save with tutorial unlocked
## - SaveGame.load_save(filename) -> Loads save and applies to current game
## - SaveGame.save_current_game() -> Updates current save with current state
## - SaveGame.get_save_list() -> Returns array of save metadata for UI

const SAVE_DIR = "user://saves/"
const SAVE_FILE_PREFIX = "save_"
const SAVE_FILE_EXTENSION = ".json"

signal save_list_changed()

# Structure for save data
var current_save_id: String = ""
const SAVE_DEBUG := false
func _log(s: String) -> void:
	if SAVE_DEBUG: print("[SaveGame] ", s)

func _ready() -> void:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.open("user://").make_dir_recursive(SAVE_DIR)
	_log("ready → SAVE_DIR ok")

func get_save_list() -> Array[Dictionary]:
	"""Returns array of save metadata dictionaries"""
	var saves: Array[Dictionary] = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return saves
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.begins_with(SAVE_FILE_PREFIX) and file_name.ends_with(SAVE_FILE_EXTENSION):
			var save_data = load_save_metadata(file_name)
			if save_data != null:
				save_data["file_name"] = file_name
				saves.append(save_data)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Sort by creation date (newest first)
	saves.sort_custom(func(a, b): return a.get("timestamp", 0) > b.get("timestamp", 0))
	
	return saves

func load_save_metadata(file_name: String) -> Dictionary:
	"""Load only the metadata portion of a save file"""
	var file_path = SAVE_DIR + file_name
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		return {}
	
	var data = json.data as Dictionary
	return data.get("metadata", {})

func create_new_save(player_name: String) -> String:
	"""Create a new save with the given player name and return the save ID"""
	var timestamp = Time.get_unix_time_from_system()
	var save_id = "%s%d" % [SAVE_FILE_PREFIX, timestamp]
	var file_name = save_id + SAVE_FILE_EXTENSION

	_log("create_new_save(name='%s')" % player_name)
	_reset_singletons()  # limpia GameState y DB.state
	
	# Initialize GameState for new game
	GameState.current_case_id = "case_demo_general"
	GameState.current_thread = ""
	GameState.set_flag("tutorial_unlocked", true)
	
	DB.load_case(GameState.current_case_id)
	var snap := DB.get_progress_snapshot()
	_log("new snapshot facts=%d chats=%d" % [
		(int)((snap.get("facts", {}) as Dictionary).size()),
		(int)((snap.get("chats", {}) as Dictionary).size())
	])
	
	var save_data = {
		"metadata": {
			"player_name": player_name,
			"timestamp": timestamp,
			"created_date": Time.get_datetime_string_from_system(false, true),
			"current_case": GameState.current_case_id,
			"save_version": "1.0"
		},
		"game_state": {
			"vars": (GameState.vars).duplicate(true),
			"inventory": (GameState.inventory).duplicate(true),
			"current_case_id": GameState.current_case_id,
			"current_thread": GameState.current_thread
		},
		"db_state": (DB.state).duplicate(true),
		"case_progress": snap
	}
	
	if save_game_data(file_name, save_data):
		current_save_id = save_id
		_log("create_new_save ok → id=%s file=%s" % [current_save_id, file_name])
		save_list_changed.emit()
		return save_id
	
	_log("create_new_save FAILED")
	return ""

func save_current_game() -> bool:
	"""Save the current game state to the current save slot"""
	if current_save_id.is_empty():
		_log("save_current_game ABORT → current_save_id vacío")
		return false
	
	var file_name = current_save_id + SAVE_FILE_EXTENSION
	
	# Get existing metadata
	var existing_metadata = load_save_metadata(file_name)
	if existing_metadata.is_empty():
		_log("save_current_game ABORT → no metadata for %s" % file_name)
		return false
	
	# Update timestamp for last save
	existing_metadata["last_saved"] = Time.get_datetime_string_from_system(false, true)
	existing_metadata["current_case"] = GameState.current_case_id

	var snap := DB.get_progress_snapshot()
	_log("save snapshot facts=%d chats=%d" % [
		(int)((snap.get("facts", {}) as Dictionary).size()),
		(int)((snap.get("chats", {}) as Dictionary).size())
	])

	var save_data = {
		"metadata": existing_metadata,
		"game_state": {
			"vars": (GameState.vars).duplicate(true),
			"inventory": (GameState.inventory).duplicate(true),
			"current_case_id": GameState.current_case_id,
			"current_thread": GameState.current_thread
		},
		"db_state": (DB.state).duplicate(true),
		"case_progress": snap
	}

	var ok := save_game_data(file_name, save_data)
	_log("save_current_game write %s → %s" % [file_name, str(ok)])
	
	return ok

func load_save(file_name: String) -> bool:
	"""Load a save file and apply it to the current game state"""
	var file_path = SAVE_DIR + file_name
	_log("load_save(%s)" % file_name)

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Could not open save file: " + file_path)
		_log("open FAIL")
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("Could not parse save file JSON")
		_log("parse FAIL")
		return false
	
	current_save_id = file_name.get_basename()
	_reset_singletons()
	_log("current_save_id=%s (after reset)" % current_save_id)

	var data = json.data as Dictionary
	var game_state = data.get("game_state", {})
	var db_state = data.get("db_state", {})
	var case_progress: Dictionary = data.get("case_progress", {}) as Dictionary
	
	# Apply loaded state
	GameState.vars = game_state.get("vars", {})
	GameState.inventory = game_state.get("inventory", {})
	GameState.current_case_id = game_state.get("current_case_id", "case_tutorial")
	GameState.current_thread = game_state.get("current_thread", "")
	
	DB.state = db_state
	_log("rehydrate → case_id='%s' thread='%s'" % [GameState.current_case_id, GameState.current_thread])

	DB.load_case(GameState.current_case_id)
	if not case_progress.is_empty():
		DB.apply_progress_snapshot(case_progress)
		_log("apply_progress_snapshot facts=%d chats=%d" % [
			(int)((case_progress.get("facts", {}) as Dictionary).size()),
			(int)((case_progress.get("chats", {}) as Dictionary).size())
		])
	else:
		_log("no case_progress in save")

	return true

func delete_save(file_name: String) -> bool:
	"""Delete a save file"""
	var file_path = SAVE_DIR + file_name
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	
	var result = dir.remove(file_name)
	if result == OK:
		save_list_changed.emit()
		return true
	
	return false

func save_game_data(file_name: String, data: Dictionary) -> bool:
	"""Helper function to save data to a file"""
	var file_path = SAVE_DIR + file_name
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not create save file: " + file_path)
		_log("write FAIL open %s" % file_path)
		return false
	
	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()
	_log("write OK bytes=%d path=%s" % [json_string.length(), file_path])
	
	return true

func get_current_save_name() -> String:
	"""Get the player name of the current save"""
	if current_save_id.is_empty():
		return ""
	
	var file_name = current_save_id + SAVE_FILE_EXTENSION
	var metadata = load_save_metadata(file_name)
	return metadata.get("player_name", "")

func _reset_singletons() -> void:
	# GameState a valores por defecto
	GameState.vars = {}
	GameState.inventory = {}
	GameState.current_case_id = ""
	GameState.current_thread = ""
	# DB
	var v: Variant = {}  # ← tipado estricto: evita el warning de Variant
	DB.state = v as Dictionary
	DB.current_case = {}
	_log("_reset_singletons done")
