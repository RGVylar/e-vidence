extends Node

var root: Node = null
var stack: Array[Node] = []

func _ready() -> void:
	print("Router listo")

func goto(scene_path: String, params: Dictionary = {}) -> void:
	var s: Node = load(scene_path).instantiate()
	if s.has_method("init"):
		s.call("init", params)
	_swap_scene(s)

func back() -> void:
	if stack.size() < 2:
		return
	var last: Node = stack.pop_back()  # ← tipado explícito para evitar Variant
	if is_instance_valid(last):
		last.queue_free()
	root.add_child(stack[-1])

func _swap_scene(new_scene: Node) -> void:
	if root == null:
		root = get_tree().current_scene
	if stack.size() > 0 and is_instance_valid(stack[-1]):
		root.remove_child(stack[-1])
		stack[-1].queue_free()
	stack.append(new_scene)
	root.add_child(new_scene)

func go(target) -> void:
	var path := ""
	if target is PackedScene:
		path = target.resource_path
	elif typeof(target) == TYPE_STRING:
		path = String(target)
	else:
		push_error("Router.go: target inválido: %s" % typeof(target))
		return

	if path.is_empty():
		push_error("Router.go: ruta vacía")
		return

	get_tree().change_scene_to_file(path)
