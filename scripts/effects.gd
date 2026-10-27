extends Node3D
signal projectile_hit(target, point, damage)
var shots=[]
var sound_enabled=false
var sounds={}
var rng=RandomNumberGenerator.new()

func _ready():
	rng.seed=40
	for entry in [["shot",.28,95.0,.65,.5],["step",.15,60.0,.35,.20],["sword",.35,170.0,.55,.28],["order",.12,330.0,.05,.12]]:
		var stream=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=22050;stream.stereo=false
		var data=PackedByteArray();var count=int(entry[1]*22050);data.resize(count*2)
		for i in range(count):
			var t=float(i)/count;var tone=sin(TAU*entry[2]*i/22050.0*(1-t*.65));var value=(tone*(1-entry[3])+rng.randf_range(-1,1)*entry[3])*pow(1-t,2)*entry[4]
			data.encode_s16(i*2,int(clampf(value,-1,1)*32700))
		stream.data=data;sounds[entry[0]]=stream

func sound(name:String,point:Vector3):
	if not sound_enabled:return
	var player=AudioStreamPlayer3D.new();player.stream=sounds[name];player.unit_size=12;player.max_distance=70;add_child(player);player.position=point;player.finished.connect(player.queue_free);player.play()

func mat(color:Color)->StandardMaterial3D:
	var m=StandardMaterial3D.new();m.albedo_color=color;m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.cull_mode=BaseMaterial3D.CULL_DISABLED
	return m

func flash(point:Vector3):
	var m=MeshInstance3D.new();var shape=SphereMesh.new();shape.radius=.16;shape.height=.32;shape.radial_segments=8;shape.rings=4;m.mesh=shape;m.material_override=mat(Color("ffd898"));m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(m);m.position=point
	var light=OmniLight3D.new();light.light_color=Color("ffad55");light.light_energy=3;light.omni_range=5;m.add_child(light)
	get_tree().create_timer(.055).timeout.connect(m.queue_free)

func shoot(origin:Vector3,end:Vector3,target):
	flash(origin);sound("shot",origin)
	var trail=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=1;mesh.bottom_radius=1;mesh.height=1;mesh.radial_segments=5;trail.mesh=mesh;trail.material_override=mat(Color("ffce80"));trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(trail)
	shots.append({"from":origin,"to":end,"target":target,"time":0.0,"duration":maxf(.035,origin.distance_to(end)/95.0),"trail":trail})
	# Ejected casing follows a short physical-looking parabola, without lasting bodies.
	var shell=MeshInstance3D.new();var casing=CylinderMesh.new();casing.top_radius=.035;casing.bottom_radius=.035;casing.height=.13;casing.radial_segments=6;shell.mesh=casing;shell.material_override=mat(Color("ad8d4e"));add_child(shell);shell.position=origin
	var fall=create_tween();var destination=origin+Vector3(rng.randf_range(.6,1.1),-.7,rng.randf_range(-.4,.4));destination.y=.06
	fall.tween_property(shell,"position",origin+Vector3(.5,.3,0),.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.tween_property(shell,"position",destination,.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_interval(1.5);fall.tween_callback(shell.queue_free)

func dust(point:Vector3,heavy=false):
	var particles=CPUParticles3D.new();add_child(particles);particles.position=point
	particles.amount=12 if heavy else 6;particles.one_shot=true;particles.explosiveness=1;particles.lifetime=.65;particles.direction=Vector3.UP;particles.spread=75;particles.gravity=Vector3(0,-1.5,0);particles.initial_velocity_min=.4;particles.initial_velocity_max=1.3 if heavy else .7
	particles.scale_amount_min=.06;particles.scale_amount_max=.13
	var shape=SphereMesh.new();shape.radius=1;shape.height=2;shape.radial_segments=5;shape.rings=3;shape.material=mat(Color(.63,.60,.49,.25));particles.mesh=shape
	particles.finished.connect(particles.queue_free);particles.emitting=true

func impact(point:Vector3,damage=0):
	dust(point,true)
	var sparks=CPUParticles3D.new();add_child(sparks);sparks.position=point;sparks.amount=10;sparks.one_shot=true;sparks.explosiveness=1;sparks.lifetime=.35;sparks.direction=Vector3.UP;sparks.spread=140;sparks.gravity=Vector3(0,-9,0);sparks.initial_velocity_min=1.5;sparks.initial_velocity_max=4;sparks.scale_amount_min=.014;sparks.scale_amount_max=.03
	var shape=BoxMesh.new();shape.size=Vector3(1,1,4);shape.material=mat(Color("ffcd80"));sparks.mesh=shape;sparks.finished.connect(sparks.queue_free);sparks.emitting=true
	if damage>0:
		var label=Label3D.new();label.text="−%d"%damage;label.font=preload("res://assets/fonts/Heading.ttf");label.font_size=48;label.pixel_size=.018;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.outline_size=0;label.modulate=Color("e9c38a");add_child(label);label.position=point+Vector3.UP*.7
		var tween=create_tween();tween.set_parallel();tween.tween_property(label,"position",label.position+Vector3.UP*1.2,.8);tween.tween_property(label,"modulate:a",0.0,.8);tween.chain().tween_callback(label.queue_free)

func sword_trail(base:Vector3,tip:Vector3,previous_tip:Vector3):
	if tip.distance_to(previous_tip)<.04:return
	var ribbon=MeshInstance3D.new();var mesh=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat(Color(.88,.71,.43,.22)))
	for vertex in [base,tip,previous_tip]:mesh.surface_add_vertex(vertex)
	mesh.surface_end();ribbon.mesh=mesh;ribbon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ribbon);get_tree().create_timer(.10).timeout.connect(ribbon.queue_free)

func _process(delta):
	for i in range(shots.size()-1,-1,-1):
		var s=shots[i];s.time+=delta
		var f=minf(1,s.time/s.duration);var front=s.from.lerp(s.to,f);var back=s.from.lerp(s.to,maxf(0,f-.20));var distance=front.distance_to(back)
		s.trail.position=(front+back)/2
		if distance>.001:s.trail.basis=Basis(Quaternion(Vector3.UP,(front-back).normalized()));s.trail.scale=Vector3(.013,distance,.013)
		if f>=1:
			projectile_hit.emit(s.target,s.to,40);s.trail.queue_free();shots.remove_at(i)
