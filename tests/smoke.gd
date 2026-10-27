extends SceneTree
var game
var checks=0
var failures=[]

func _initialize():call_deferred("run")
func check(condition:bool,message:String):
	checks+=1
	if not condition:failures.append(message);push_error("CHECK FAILED: "+message)
	else:print("PASS ",message)
func frames(n:int):
	for _i in range(n):await physics_frame
func run():
	game=load("res://scenes/range.tscn").instantiate();root.add_child(game)
	await frames(5)
	check(game.ready_for_tests,"native Godot range starts")
	check(game.world.targets.size()==6,"six functional training targets")
	check(game.actor.skeleton.get_bone_count()==16,"supplied model has a real 16-bone skin")
	var expected=["idle_bolter","idle_sword","walk_bolter","walk_sword","run_bolter","run_sword","aim_bolter","fire_bolter","reload_bolter","draw_bolter","draw_sword","sword_slash_left","sword_slash_right","sword_overhead"]
	for clip in expected:
		check(game.actor.player.has_animation(clip),"skeletal clip: "+clip)
		if game.actor.player.has_animation(clip):check(game.actor.player.get_animation(clip).get_track_count()>=14,"bone tracks exist: "+clip)
		print("ANIMATION ",clip," TRACKS ",game.actor.player.get_animation(clip).get_track_count())
	check(game.actor.bolter.get_parent()==game.actor.hand_socket,"extracted bolter is held at hand socket")
	check(game.actor.sword.get_parent()==game.actor.back_socket,"extracted sword is stowed")
	var route=game.navigation.path_to(Vector3(-12,0,8),Vector3(-12,0,-4))
	check(route.size()>1,"route goes around cover")
	var previous=Vector3(-12,0,8)
	for point in route:check(game.navigation.clear_line(previous,point),"route segment avoids cover");previous=point
	game.actor.order_move(Vector3(0,0,9));await frames(240)
	check(Vector2(game.actor.position.x,game.actor.position.z).distance_to(Vector2(0,9))<.5,"Titus reaches a movement order")
	game.actor.order_move(Vector3(10,0,6));game.actor.order_move(Vector3(16,0,0),true)
	check(game.actor.path.size()>=2,"shift-style queue retains both destinations")
	game.actor.stop();check(game.actor.path.is_empty(),"stop clears orders")
	game.reset_range();await frames(3);game.actor.order_attack(game.world.targets[2]);await frames(180)
	check(game.kills>=1 and game.hits>=4,"bolter projectiles hit and destroy a target")
	check(game.actor.ammo<30,"live fire consumes ammunition")
	game.actor.stop();await frames(20);game.actor.reload();check(game.actor.action=="reload","reload animation starts")
	await frames(140);check(game.actor.ammo==30,"reload replenishes the magazine")
	game.actor.switch_weapon("sword");await frames(70)
	check(game.actor.weapon=="sword","draw clip changes equipped weapon")
	check(game.actor.sword.get_parent()==game.actor.hand_socket and game.actor.bolter.get_parent()==game.actor.back_socket,"both original weapons exchange sockets")
	game.reset_range();await frames(3);game.actor.switch_weapon("sword");await frames(70);game.actor.order_attack(game.world.targets[2]);await frames(500)
	check(game.kills>=1,"sword orders close distance and damage at the clip contact")
	check(game.actor.attacks>=2,"melee combo executes distinct attacks")
	game.actor.stop();await frames(90);game.actor.direct=true
	var key=InputEventKey.new();key.physical_keycode=KEY_D;key.pressed=true;Input.parse_input_event(key)
	var start=game.actor.position;await frames(60);key.pressed=false;Input.parse_input_event(key)
	check(game.actor.position.distance_to(start)>1,"direct-control motion uses the character controller")
	game.reset_range();await frames(3);game.actor.order_attack(game.world.targets[0]);await frames(360)
	check(game.hits>0,"attack order finds a firing lane around intervening cover")
	print("GODOT TESTS: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty():print(failures)
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
