extends Node

## Localization System for E-vidence
##
## Handles multi-language support with automatic detection and manual selection.
## Provides tr() function for translating strings throughout the game.
##
## Usage:
## - Localization.tr("hello_world") -> Returns translated string
## - Localization.set_language("en") -> Changes active language
## - Localization.get_available_languages() -> Returns array of supported languages

const LOCALIZATION_DIR = "res://localization/"
const DEFAULT_LANGUAGE = "es"
const FALLBACK_LANGUAGE = "en"

var current_language: String = ""
var translations: Dictionary = {}
var available_languages: Array[String] = []

signal language_changed(new_language: String)

func _ready() -> void:
	_load_available_languages()
	_detect_and_set_initial_language()

func _load_available_languages() -> void:
	"""Scan localization directory for available language files"""
	available_languages.clear()
	
	var dir = DirAccess.open(LOCALIZATION_DIR)
	if dir == null:
		push_warning("Localization directory not found: " + LOCALIZATION_DIR)
		available_languages = [DEFAULT_LANGUAGE]
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json") and not file_name.begins_with("."):
			var lang_code = file_name.get_basename()
			available_languages.append(lang_code)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	if available_languages.is_empty():
		available_languages = [DEFAULT_LANGUAGE]
	
	available_languages.sort()
	print("[Localization] Available languages: ", available_languages)

func _detect_and_set_initial_language() -> void:
	"""Detect system language and set initial language"""
	# First check if there's a saved preference
	var saved_language = GameState.vars.get("preferred_language", "")
	if saved_language != "" and available_languages.has(saved_language):
		set_language(saved_language)
		return
	
	# Try to detect system language
	var system_locale = OS.get_locale()
	var system_language = system_locale.substr(0, 2).to_lower()
	
	print("[Localization] System locale: ", system_locale, " -> language: ", system_language)
	
	# Check if system language is available
	if available_languages.has(system_language):
		set_language(system_language)
	elif available_languages.has(DEFAULT_LANGUAGE):
		set_language(DEFAULT_LANGUAGE)
	elif available_languages.has(FALLBACK_LANGUAGE):
		set_language(FALLBACK_LANGUAGE)
	else:
		# Use first available language as last resort
		set_language(available_languages[0])

func set_language(language_code: String) -> bool:
	"""Set the active language and load its translations"""
	if not available_languages.has(language_code):
		push_warning("Language not available: " + language_code)
		return false
	
	if current_language == language_code:
		return true  # Already set
	
	if _load_language_file(language_code):
		current_language = language_code
		GameState.set_flag("preferred_language", language_code)
		language_changed.emit(language_code)
		print("[Localization] Language changed to: ", language_code)
		return true
	
	return false

func _load_language_file(language_code: String) -> bool:
	"""Load translations from language file"""
	var file_path = LOCALIZATION_DIR + language_code + ".json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		push_error("Could not open language file: " + file_path)
		return false
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("Could not parse language file: " + file_path)
		return false
	
	translations = json.data as Dictionary
	print("[Localization] Loaded ", translations.size(), " translations for ", language_code)
	return true

func tr(key: String, default_text: String = "") -> String:
	"""Translate a key to the current language"""
	if translations.has(key):
		return String(translations[key])
	
	# If default text is provided, use it
	if default_text != "":
		return default_text
	
	# Try fallback language if current language is not the fallback
	if current_language != FALLBACK_LANGUAGE and available_languages.has(FALLBACK_LANGUAGE):
		var fallback_path = LOCALIZATION_DIR + FALLBACK_LANGUAGE + ".json"
		var fallback_file = FileAccess.open(fallback_path, FileAccess.READ)
		
		if fallback_file != null:
			var fallback_json = JSON.new()
			if fallback_json.parse(fallback_file.get_as_text()) == OK:
				var fallback_translations = fallback_json.data as Dictionary
				fallback_file.close()
				if fallback_translations.has(key):
					return String(fallback_translations[key])
			fallback_file.close()
	
	# Return the key itself as last resort
	push_warning("Translation missing for key: " + key)
	return key

func get_available_languages() -> Array[String]:
	"""Get list of available language codes"""
	return available_languages.duplicate()

func get_current_language() -> String:
	"""Get current language code"""
	return current_language

func get_language_display_name(language_code: String) -> String:
	"""Get human-readable name for a language code"""
	var names = {
		"es": "Español",
		"en": "English",
		"fr": "Français",
		"de": "Deutsch",
		"it": "Italiano",
		"pt": "Português"
	}
	return names.get(language_code, language_code.to_upper())