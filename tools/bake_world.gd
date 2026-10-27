extends SceneTree
func _initialize():call_deferred("run")
func own_children(node:Node,scene_root:Node):
	for child in node.get_children():
		child.owner=scene_root
		if child.has_meta("target"):child.remove_meta("target")
		own_children(child,scene_root)
func run():
	var world=load("res://scripts/world.gd").new();world.name="BastionArchitecture";root.add_child(world)
	for i in range(20):await process_frame
	var marker=Node3D.new();marker.name="BakedGeometry";world.add_child(marker)
	own_children(world,world)
	var scene=PackedScene.new();var result=scene.pack(world)
	if result!=OK:push_error("World packing failed");quit(1);return
	result=ResourceSaver.save(scene,"res://scenes/architecture.tscn")
	print("EDITABLE GODOT ARCHITECTURE SAVED ",result)
	quit(0 if result==OK else 1)
