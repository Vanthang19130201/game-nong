extends RefCounted

const TYPES: Dictionary = {
	"normal_rock": {"min_stone":2,"max_stone":2,"color":Color(0.5,0.5,0.55)},
	"large_rock": {"min_stone":3,"max_stone":3,"color":Color(0.66,0.63,0.55)},
	"dark_rock": {"min_stone":2,"max_stone":3,"color":Color(0.27,0.29,0.36)}
}
static var texture_paths: Dictionary = {}
static var textures_scanned: bool = false
static var _textures: Dictionary = {}

static func texture_for(type: String) -> Texture2D:
	if not textures_scanned:
		textures_scanned = true
		var paths: Array[String] = []
		_find_textures("res://assets",paths)
		paths.sort()
		var remaining: Array[String] = paths.duplicate()
		# Prefer explicitly named files, then assign other rock artwork consistently.
		for id in TYPES:
			for path in paths:
				if path.get_file().get_basename().to_lower() == id:
					texture_paths[id] = path
					remaining.erase(path)
					break
		for id in TYPES:
			if not texture_paths.has(id) and not remaining.is_empty():
				texture_paths[id] = remaining.pop_front()
	if texture_paths.is_empty():
		return null
	var path: String = texture_paths.get(type,texture_paths.values()[0])
	if not _textures.has(path):
		_textures[path] = load(path) as Texture2D
	return _textures[path] as Texture2D

static func _find_textures(directory: String, paths: Array[String]) -> void:
	for entry in ResourceLoader.list_directory(directory):
		var path: String = directory.path_join(entry)
		if entry.ends_with("/"):
			_find_textures(path,paths)
		elif path.get_extension().to_lower() in ["png","webp","jpg","jpeg","svg"]:
			var name: String = path.to_lower()
			if name.contains("rock") or name.contains("stone"):
				paths.append(path)
