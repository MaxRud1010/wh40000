extends Node3D
const World=preload("res://scripts/world.gd")
const Titus=preload("res://scripts/titus.gd")
const CameraRig=preload("res://scripts/camera.gd")
const Hud=preload("res://scripts/hud.gd")
const Effects=preload("res://scripts/effects.gd")
const Navigation=preload("res://scripts/navigation.gd")
var world
var actor
var camera
var hud
var fx
var navigation=Navigation.new()
var kills=0
var hits=0
var attack_mode=false
var rotate_drag=false
var drag_start=Vector2.INF
var ring:MeshInstance3D
var marker:MeshInstance3D
var route:MeshInstance3D
var marker_timer=0.0
var route_timer=0.0
var previous_tip=Vector3.ZERO
var capture_frames=0
var ready_for_tests=false

func _ready():
	_setup_light()
	world=get_node("BastionArchitecture")
	fx=Effects.new();fx.name="CombatEffects";add_child(fx);fx.projectile_hit.connect(_projectile_hit)
	actor=Titus.new();actor.name="Titus";add_child(actor);actor.position=Vector3(-4,.05,8);actor.rotation.y=-.5
	actor.attack_requested.connect(_attack_contact)
	actor.footstep.connect(func(point,run):fx.dust(point,run);fx.sound("step",point);camera.shake=maxf(camera.shake,.012 if run else .004))
	camera=CameraRig.new();camera.actor=actor;add_child(camera)
	var canvas=CanvasLayer.new();canvas.name="TacticalInterface";add_child(canvas)
	hud=Hud.new();hud.game=self;canvas.add_child(hud);hud.command.connect(_command)
	for target in world.targets:
		target.hit.connect(func(_t,_amount):hits+=1;hud.objectives[2]=true)
		target.destroyed.connect(func(t):kills+=1;hud.notify("МИШЕНЬ %02d · УНИЧТОЖЕНА"%(t.target_id+1)))
	ring=_ring(1.0,1.035,Color("c1d09d"));ring.position.y=.055
	marker=_ring(.35,.39,Color("d5ad70"));marker.visible=false
	route=MeshInstance3D.new();route.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(route)
	hud.notify("ТИТУС НА СВЯЗИ · ПОЛИГОН ГОТОВ")
	ready_for_tests=true
	if "--showcase" in OS.get_cmdline_user_args():
		camera.zoom=13;camera.pitch=.58;camera.focus_point=Vector3(actor.position.x,0,actor.position.z);camera.yaw=.9
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--clip="):
				var clip=argument.trim_prefix("--clip=")
				if clip.contains("sword"):actor._equip("sword")
				actor.action="showcase";actor.action_duration=100;actor._play(clip,0)
				actor.player.seek(.36,true);actor.player.speed_scale=0
	if "--capture" in OS.get_cmdline_user_args():capture_frames=90

func _setup_light():
	var env=WorldEnvironment.new();env.name="Atmosphere";var environment=Environment.new();env.environment=environment
	environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("7d8a84")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("bbcbbf");environment.ambient_light_energy=.38
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled=true;environment.fog_light_color=Color("8c9990");environment.fog_density=.003
	add_child(env)
	var sun=DirectionalLight3D.new();sun.name="LateAfternoonSun";sun.light_color=Color("ffe0ae");sun.light_energy=.85;sun.shadow_enabled=true;sun.directional_shadow_max_distance=100;add_child(sun);sun.position=Vector3(-18,32,12);sun.look_at(Vector3.ZERO)
	var fill=DirectionalLight3D.new();fill.light_color=Color("a3bac6");fill.light_energy=.20;add_child(fill);fill.rotation_degrees=Vector3(-35,-135,0)

func _ring(inner:float,outer:float,color:Color)->MeshInstance3D:
	var node=MeshInstance3D.new();var shape=TorusMesh.new();shape.inner_radius=inner;shape.outer_radius=outer;shape.rings=80;shape.ring_segments=8;node.mesh=shape;var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);return node

func live_targets()->int:
	var count=0
	for t in world.targets:
		if t.alive:count+=1
	return count

func pick_target(point:Vector2):
	var query=PhysicsRayQueryParameters3D.create(camera.project_ray_origin(point),camera.project_ray_origin(point)+camera.project_ray_normal(point)*250,2)
	var result=get_world_3d().direct_space_state.intersect_ray(query)
	return result.collider.get_meta("target",null) if not result.is_empty() else null

func _unhandled_input(event):
	if not ready_for_tests:return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if hud.help_open:hud.toggle_help()
				else:actor.stop();attack_mode=false
			KEY_F1:hud.toggle_help()
			KEY_1:_command("bolter")
			KEY_2:_command("sword")
			KEY_R:_command("reload")
			KEY_H:_command("stop")
			KEY_SPACE:_command("focus")
			KEY_CTRL:_command("direct")
			KEY_A:
				if not actor.direct:_command("attack")
			KEY_M:
				if not actor.direct:_command("move")
	if event is InputEventMouseButton:
		var p=event.position
		if event.button_index==MOUSE_BUTTON_MIDDLE:rotate_drag=event.pressed;return
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed:camera.zoom=clampf(camera.zoom-2,16,65);return
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed:camera.zoom=clampf(camera.zoom+2,16,65);return
		if hud.blocks_world(p):return
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
			if actor.direct:_command("direct");return
			var target=pick_target(p)
			if target!=null:actor.order_attack(target);hud.notify("ЦЕЛЬ ПРИНЯТА · К БОЮ");fx.sound("order",actor.position)
			else:
				var destination=camera.ground_point(p)
				if actor.order_move(destination,Input.is_physical_key_pressed(KEY_SHIFT),event.double_click):
					hud.objectives[0]=true;marker.position=actor.path[actor.path.size()-1]+Vector3.UP*.06;marker_timer=1.3;fx.sound("order",actor.position)
				else:hud.notify("МАРШРУТ НЕДОСТУПЕН")
			actor.selected=true
		if event.button_index==MOUSE_BUTTON_LEFT:
			if actor.direct:actor.manual_fire=event.pressed
			elif event.pressed:
				if attack_mode:
					var target=pick_target(p)
					if target!=null:actor.order_attack(target)
					else:actor._attack(null,camera.ground_point(p)+Vector3.UP*1.5)
				else:
					drag_start=p
					var query=PhysicsRayQueryParameters3D.create(camera.project_ray_origin(p),camera.project_ray_origin(p)+camera.project_ray_normal(p)*250,4)
					actor.selected=not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
			elif drag_start!=Vector2.INF:
				if drag_start.distance_to(p)>8:actor.selected=Rect2(drag_start,p-drag_start).abs().has_point(camera.unproject_position(actor.position+Vector3.UP))
				drag_start=Vector2.INF
	if event is InputEventMouseMotion and rotate_drag:
		camera.yaw-=event.relative.x*.006;camera.pitch=clampf(camera.pitch+event.relative.y*.004,.5,1.25)

func _command(value:String):
	match value:
		"bolter","sword":
			actor.switch_weapon(value);hud.objectives[1]=true
		"reload":actor.reload()
		"stop":actor.stop();hud.notify("ПРИКАЗ · СТОП")
		"focus":camera.follow=true
		"move":attack_mode=false;hud.notify("ПКМ ПО ЗЕМЛЕ · ПРИКАЗ ДВИЖЕНИЯ")
		"attack":attack_mode=true;hud.notify("ЛКМ ПО МИШЕНИ · АТАКА")
		"direct":
			actor.direct=not actor.direct;actor.stop();actor.selected=true
			hud.notify("ПРЯМОЙ КОНТРОЛЬ · WASD / ЛКМ" if actor.direct else "ТАКТИЧЕСКИЙ РЕЖИМ · ПКМ — ПРИКАЗ")
		"sound":fx.sound_enabled=not fx.sound_enabled;hud.buttons.sound.text="ЗВУК ВКЛ." if fx.sound_enabled else "ЗВУК ВЫКЛ."
		"reset":reset_range()

func reset_range():
	actor.stop();actor.action="";actor.current_clip="";actor.ammo=30;actor.pending_weapon="";actor.direct=false;actor.velocity=Vector3.ZERO;actor.position=Vector3(-4,.05,8);actor._equip("bolter")
	for t in world.targets:t.restore()
	for shot in fx.shots:shot.trail.queue_free()
	fx.shots.clear();kills=0;hits=0;camera.follow=true;hud.notify("ПОЛИГОН ВОССТАНОВЛЕН")

func _attack_contact(target,point:Vector3,melee:bool):
	if melee:
		fx.sound("sword",actor.position)
		if target==null:
			for t in world.targets:
				if t.alive and t.position.distance_to(actor.position)<3.1:target=t;break
		if is_instance_valid(target) and target.alive and target.position.distance_to(actor.position)<3.25:
			target.take_damage(80);fx.impact(target.position+Vector3.UP*1.4,80);camera.shake=.04
	else:
		var destination=target.global_position+Vector3.UP*1.5 if is_instance_valid(target) else point
		fx.shoot(actor.muzzle.global_position,destination,target);camera.shake=.025

func _projectile_hit(target,point:Vector3,damage:int):
	if is_instance_valid(target) and target.alive:target.take_damage(damage);fx.impact(point,damage)
	else:fx.impact(point)

func _process(delta):
	if not ready_for_tests:return
	var mouse=get_viewport().get_mouse_position()
	if actor.direct:
		var x=float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
		var z=float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))
		actor.manual_move=Vector3(x,0,z).rotated(Vector3.UP,camera.yaw).normalized();actor.running=Input.is_physical_key_pressed(KEY_SHIFT)
		var target=pick_target(mouse);actor.manual_target=target
		actor.manual_aim=target.position+Vector3.UP*1.5 if target!=null else camera.ground_point(mouse)+Vector3.UP*1.5
		camera.focus_point=camera.focus_point.lerp(Vector3(actor.position.x,0,actor.position.z),minf(1,delta*7))
	else:
		var x=float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT))
		var z=float(Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_UP))
		if x!=0 or z!=0:camera.follow=false;camera.focus_point+=Vector3(x,0,z).rotated(Vector3.UP,camera.yaw)*delta*15
	ring.position=Vector3(actor.position.x,.06,actor.position.z);ring.visible=actor.selected
	marker_timer=maxf(0,marker_timer-delta);marker.visible=marker_timer>0
	route_timer-=delta
	if route_timer<0:_draw_route();route_timer=.1
	if actor.action=="melee" and actor.action_time>.2 and actor.action_time<.65:
		fx.sword_trail(actor.hand_socket.global_position,actor.sword_tip.global_position,previous_tip)
	previous_tip=actor.sword_tip.global_position
	if capture_frames>0:
		capture_frames-=1
		if capture_frames==0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/godot-showcase.png" if "--showcase" in OS.get_cmdline_user_args() else "res://docs/godot-range.png")
			print("GODOT_SCREENSHOT_SAVED");get_tree().quit()

func _draw_route():
	if actor.path.is_empty():route.mesh=null;return
	var mesh=ImmediateMesh.new();var mat=StandardMaterial3D.new();mat.albedo_color=Color("bdc998");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,mat);mesh.surface_add_vertex(Vector3(actor.position.x,.06,actor.position.z))
	for point in actor.path:mesh.surface_add_vertex(point+Vector3.UP*.06)
	mesh.surface_end();route.mesh=mesh
