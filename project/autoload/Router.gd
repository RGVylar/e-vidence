extends Node

var root: Node = null
var stack: Array[Node] = []


const ROUTER_DEBUG := false
func _log(s: String) -> void:
	if ROUTER_DEBUG: print("[ROUTER] ", s)

func _ready() -> void:
	_log("ready")

## Changes the current scene to a new scene while maintaining a scene stack.
## This method instantiates the new scene, initializes it with parameters if possible,
## and manages the scene stack for navigation.
## @param scene_path: String - The path to the scene file to load
## @param params: Dictionary - Optional parameters to pass to the scene's init method
func goto(scene_path: String, params: Dictionary = {}) -> void:
	var s: Node = load(scene_path).instantiate()
	if s.has_method("init"):
		s.call("init", params)
	_swap_scene(s)

## Navigates back to the previous scene in the stack.
## If there aren't enough scenes in the stack (less than 2), the method does nothing.
## The current scene is removed and freed from memory.
func back() -> void:
	if stack.size() < 2:
		return
	var last: Node = stack.pop_back()
	if is_instance_valid(last):
		last.queue_free()
	root.add_child(stack[-1])

## Internal method to handle scene swapping logic.
## Manages the scene stack, removes the current scene, and adds the new one.
## @param new_scene: Node - The new scene instance to swap to
func _swap_scene(new_scene: Node) -> void:
	if root == null:
		root = get_tree().current_scene
	if stack.size() > 0 and is_instance_valid(stack[-1]):
		root.remove_child(stack[-1])
		stack[-1].queue_free()
	stack.append(new_scene)
	root.add_child(new_scene)

## Changes the current scene directly without maintaining a stack.
## Supports both PackedScene and String path inputs.
## @param target: PackedScene|String - The target scene or path to change to
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
