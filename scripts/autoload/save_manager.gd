extends Node
## SaveManager — JSON save/load to user://, with autosave.
## Autosave happens every time you sleep and every AUTOSAVE_SECONDS while playing.

const SAVE_PATH := "user://bloomfolk_save.json"
const AUTOSAVE_SECONDS := 120.0

var _timer := 0.0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(quiet: bool = false) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		Events.toast.emit("Save failed!", Color("ff6a6a"))
		return false
	f.store_string(JSON.stringify(GameState.to_dict()))
	f.close()
	if not quiet:
		Events.toast.emit("Game saved.", Color("9fd4ff"))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		Events.toast.emit("Save file is corrupted.", Color("ff6a6a"))
		return false
	GameState.from_dict(data)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _process(delta: float) -> void:
	if not GameState.playing or get_tree().paused:
		return
	_timer += delta
	if _timer >= AUTOSAVE_SECONDS:
		_timer = 0.0
		Events.open_panel.emit("_sync_player", null)   # world pushes player pos into state
		save_game(true)
