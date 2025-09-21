# Multi-Language Support Documentation

## Overview

The e-vidence game now includes a comprehensive multi-language localization system that supports automatic language detection, manual language switching, and persistent language preferences.

## Features

### Automatic Language Detection
- Detects system language using `OS.get_locale()` on first startup
- Falls back to Spanish (es) if system language is not supported
- Falls back to English (en) if Spanish is not available

### Manual Language Selection
- Options button in main menu provides language selection dialog
- Real-time language switching without restart
- Clear display of current language

### Language Persistence
- Language preference is automatically saved in GameState
- Persistent across game sessions
- Saved language preference overrides automatic detection

## Usage

### For Players

1. **First Launch**: Game automatically detects your system language
2. **Manual Change**: Click "Options" in main menu → Select preferred language
3. **Instant Update**: UI updates immediately when language is changed
4. **Persistent**: Your language choice is remembered for future sessions

### For Developers

#### Adding New Strings

1. Add the string key and text to all language files in `project/localization/`:
   ```json
   {
     "new_key": "Spanish text",
     ...
   }
   ```

2. Use the localization system in GDScript:
   ```gdscript
   # Simple usage
   label.text = Localization.tr("new_key")
   
   # With fallback text
   label.text = Localization.tr("new_key", "Fallback text")
   
   # With format strings
   label.text = Localization.tr("format_key", "Default: %s") % value
   ```

#### Adding New Languages

1. Create a new JSON file in `project/localization/` (e.g., `fr.json` for French)
2. Copy all keys from an existing language file
3. Translate all values to the new language
4. Add the language display name to `Localization.get_language_display_name()`

#### Updating UI for Language Changes

Connect to the language change signal:
```gdscript
func _ready() -> void:
    Localization.language_changed.connect(_on_language_changed)

func _on_language_changed(new_language: String) -> void:
    _update_ui_text()
```

## File Structure

```
project/
├── autoload/
│   └── Localization.gd          # Core localization system
├── localization/
│   ├── es.json                  # Spanish translations (base)
│   └── en.json                  # English translations
└── project.godot               # Localization autoload registered
```

## Language Files

### Spanish (es.json) - Base Language
- Contains all game text in Spanish
- Used as the reference for key consistency
- Default fallback language

### English (en.json) - Primary Alternative
- Complete English translation
- Secondary fallback if Spanish fails
- Reference implementation for additional languages

## Supported Languages

Currently supported:
- **Spanish (es)** - Base language, fully supported
- **English (en)** - Complete translation

Easily extensible for:
- French (fr)
- German (de)
- Italian (it)
- Portuguese (pt)
- And any other language

## API Reference

### Localization Singleton

#### Methods

- `tr(key: String, default_text: String = "") -> String`
  - Translate a key to current language
  - Returns fallback text or key if translation missing

- `set_language(language_code: String) -> bool`
  - Change active language
  - Returns true if successful

- `get_current_language() -> String`
  - Get current language code

- `get_available_languages() -> Array[String]`
  - Get list of available language codes

- `get_language_display_name(language_code: String) -> String`
  - Get human-readable language name

#### Signals

- `language_changed(new_language: String)`
  - Emitted when language changes
  - Use to update UI text

## Translation Keys

### Common UI Elements
- `load_game`, `new_game`, `delete`, `create`, `cancel`
- `back`, `exit`, `options`, `language`, `yes`, `no`, `ok`

### Game-Specific
- `case_loaded`, `case_load_error`, `player_case_format`
- `no_saves`, `created_date`, `last_saved`
- `no_evidence`, `present_evidence`

### Error Messages
- `load_error_title`, `load_error_message`
- `delete_confirmation`, `enter_name_required`

## Implementation Notes

### Performance
- Language files are loaded on demand
- Fallback language lookup is cached
- Minimal memory footprint

### Error Handling
- Graceful fallback for missing translations
- Warning messages for missing keys
- Robust JSON parsing with error recovery

### Extensibility
- Easy to add new languages
- Modular translation system
- Future-proof architecture

## Testing

Use the provided test script to validate localization files:
```bash
python3 test_localization.py
```

The test validates:
- JSON file syntax
- Key consistency between languages
- Presence of essential keys
- File structure integrity