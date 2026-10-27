extends Node3D
const TargetScript=preload("res://scripts/target.gd")
const Nav=preload("res://scripts/navigation.gd")
var targets=[]
var stone: StandardMaterial3D
var dark: StandardMaterial3D
var steel: StandardMaterial3D
var gold: StandardMaterial3D
var paint: StandardMaterial3D

func material(color:Color,metallic=0.0,roughness=.8)->StandardMaterial3D:
	var m=StandardMaterial3D.new(); m.albedo_color=color; m.metallic=metallic; m.roughness=roughness
	return m

func box(parent:Node, size:Vector3, pos:Vector3, mat:Material, collision=false)->Node3D:
	var node:Node3D=StaticBody3D.new() if collision else Node3D.new()
	parent.add_child(node); node.position=pos
	var mesh=MeshInstance3D.new(); var shape=BoxMesh.new(); shape.size=size; mesh.mesh=shape; mesh.material_override=mat
	node.add_child(mesh)
	if collision:
		var c=CollisionShape3D.new(); var s=BoxShape3D.new(); s.size=size; c.shape=s; node.add_child(c)
	return node

func cylinder(parent:Node,radius:float,height:float,pos:Vector3,mat:Material)->MeshInstance3D:
	var mesh=MeshInstance3D.new(); var shape=CylinderMesh.new(); shape.top_radius=radius; shape.bottom_radius=radius; shape.height=height; shape.radial_segments=16; mesh.mesh=shape; mesh.material_override=mat;parent.add_child(mesh);mesh.position=pos;return mesh

func label(parent:Node,text:String,pos:Vector3,size:float,font_size=70)->Label3D:
	var l=Label3D.new(); l.text=text; l.font=preload("res://assets/fonts/Heading.ttf"); l.font_size=font_size;l.pixel_size=size;l.modulate=Color("c4bd9b");l.outline_size=0;l.no_depth_test=false;parent.add_child(l);l.position=pos;return l

func floor_text(text:String,pos:Vector3,size=.015,font_size=70):
	var l=label(self,text,pos,size,font_size);l.rotation.x=-PI/2

func _ready():
	if has_node("BakedGeometry"):
		for child in get_children():
			if child.get_script()==TargetScript:
				child.target_id=int(str(child.name).trim_prefix("Target"))-1
				targets.append(child)
		return
	stone=material(Color("71796f"));dark=material(Color("303b37"),.25);steel=material(Color("5c655c"),.7,.5);gold=material(Color("b2a079"),.6);paint=material(Color("aca17e"))
	var groundmat=material(Color("8a8c7c"))
	var noise=FastNoiseLite.new();noise.frequency=.045;noise.fractal_octaves=4
	var tex=NoiseTexture2D.new();tex.width=512;tex.height=512;tex.noise=noise
	var ramp=Gradient.new();ramp.set_color(0,Color("4d564b"));ramp.set_color(1,Color("767e6b"));tex.color_ramp=ramp
	groundmat.albedo_texture=tex;groundmat.uv1_scale=Vector3(15,15,1)
	box(self,Vector3(200,.3,200),Vector3(0,-.2,0),groundmat,true)
	box(self,Vector3(58,.12,52),Vector3(0,-.04,-2),groundmat)
	var seam=material(Color("626c5f"))
	for x in range(-28,29,4): box(self,Vector3(.02,.008,50),Vector3(x,.025,-2),seam)
	for z in range(-26,23,4): box(self,Vector3(56,.008,.02),Vector3(0,.025,z),seam)
	for x in [-24,24]: box(self,Vector3(.1,.02,43),Vector3(x,.04,-1),paint)
	for z in [-19,15]: box(self,Vector3(48,.02,.1),Vector3(0,.04,z),paint)
	for i in range(38):
		for z in [6.4,-5.8]: box(self,Vector3(.65,.02,.1),Vector3(-23+i*1.25,.04,z),paint)
	floor_text("FIRING LINE",Vector3(4,.055,8.1),.018)
	floor_text("VII",Vector3(-11,.055,10),.055,110)
	floor_text("IMPERIAL PROVING GROUND",Vector3(0,.055,19),.02)
	box(self,Vector3(61,3.4,2),Vector3(0,1.7,-26),dark,true)
	box(self,Vector3(61,.4,2.7),Vector3(0,3.5,-26),stone)
	for x in range(-28,29,7):
		box(self,Vector3(1.4,5.6,3.4),Vector3(x,2.8,-25.5),stone)
		box(self,Vector3(1.65,.3,3.7),Vector3(x,5.6,-25.5),gold)
		var crown=box(self,Vector3(1.2,1.5,1.2),Vector3(x,6.4,-25.5),dark);crown.rotation.z=PI/4
	var gate=Node3D.new();gate.name="CitadelGate";add_child(gate);gate.position=Vector3(-6,0,-26)
	box(gate,Vector3(10,10,3),Vector3(0,5,0),stone)
	box(gate,Vector3(7,7.5,.25),Vector3(0,3.8,1.55),dark)
	for x in [-4.1,4.1]:
		box(gate,Vector3(1,10.8,4),Vector3(x,5.4,.2),steel)
		box(gate,Vector3(1.5,.35,4.4),Vector3(x,10.7,.2),gold)
		box(gate,Vector3(.25,7,.3),Vector3(x,4.3,2.25),gold)
	box(gate,Vector3(10.5,.35,4),Vector3(0,10.4,.1),gold)
	for i in range(14):box(gate,Vector3(.09,7,.2),Vector3(-3+i*.48,3.6,1.72),steel)
	for y in [1,2.6,4.2,5.8]:box(gate,Vector3(6.4,.08,.18),Vector3(0,y,1.9),steel)
	label(gate,"VII",Vector3(0,8.9,1.8),.020,110)
	label(gate,"BASTION",Vector3(0,7.8,1.8),.010,50)
	var glow=material(Color("ffb65a"));glow.emission_enabled=true;glow.emission=Color("ff943d");glow.emission_energy_multiplier=2
	for x in [-3.4,3.4]:
		box(gate,Vector3(.2,.65,.2),Vector3(x,6.6,2),glow)
		var lamp=OmniLight3D.new();lamp.light_color=Color("ffa255");lamp.light_energy=2;lamp.omni_range=5;gate.add_child(lamp);lamp.position=Vector3(x,6.4,2.5)
	for x in [-30,30]:
		box(self,Vector3(2,3,49),Vector3(x,1.5,-2),dark,true)
		box(self,Vector3(2.3,.35,49),Vector3(x,3.1,-2),stone)
		for z in range(-21,22,7):
			box(self,Vector3(3.7,5.2,1.8),Vector3(x,2.6,z),stone)
			box(self,Vector3(4,.25,2.2),Vector3(x,5.25,z),gold)
			box(self,Vector3(1.2,1,1.2),Vector3(x,5.8,z),steel)
	for cover in Nav.COVER:
		var p=cover.get_center();var w=cover.size.x;var d=cover.size.y
		if w>4:
			box(self,Vector3(w,.5,d+1),Vector3(p.x,.25,p.y),stone,true)
			box(self,Vector3(w,1.5,d),Vector3(p.x,1.15,p.y),stone,true)
			box(self,Vector3(w+.1,.15,d+.1),Vector3(p.x,1.95,p.y),steel)
			for i in range(int(w/.5)):
				var stripe=box(self,Vector3(.28,.25,.03),Vector3(p.x-w/2+i*.5,1.65,p.y+d/2+.02),paint if i%2==0 else dark);stripe.rotation.z=.25
		else:
			box(self,Vector3(w,1.8,d),Vector3(p.x,.9,p.y),steel,true)
			for y in [.15,1.65]:box(self,Vector3(w+.05,.12,d+.05),Vector3(p.x,y,p.y),dark)
			for side in [-1,1]:box(self,Vector3(.16,1.9,d+.08),Vector3(p.x+side*(w/2-.2),.95,p.y),gold)
			box(self,Vector3(w*.4,.65,.03),Vector3(p.x,.9,p.y+d/2+.02),dark)
	for i in range(6): _make_target(i,Vector3([-18,-11,-4,4,11,19][i],0,-14 if i%2 else -12))
	var rust=material(Color("875a3e"),.4)
	for i in range(8):
		var x=-26 if i%2==0 else 26;var z=-17+floori(i/2.0)*10
		cylinder(self,.42,1.15,Vector3(x,.57,z),rust)
		for y in [.2,.9]:cylinder(self,.44,.06,Vector3(x,y,z),dark)
	for i in range(12):
		var h=8+i*17%11;box(self,Vector3(5+i%3*2,h,8),Vector3(-55+i*10,h/2.0,-40-i%3*6),dark)
	# Controlled clutter, kept outside navigable paths.
	var rng=RandomNumberGenerator.new();rng.seed=7
	for i in range(70):
		var x=rng.randf_range(-28,28);var z=rng.randf_range(-24,-20)
		var rock=box(self,Vector3(rng.randf_range(.1,.4),.1,rng.randf_range(.1,.35)),Vector3(x,.06,z),stone);rock.rotation.y=rng.randf()*TAU

func _make_target(id:int,p:Vector3):
	var t=TargetScript.new();t.name="Target%02d"%(id+1);t.target_id=id;add_child(t);t.position=p;targets.append(t)
	box(t,Vector3(3.6,.22,3),Vector3(0,.12,0),dark)
	for side in [-1,1]:box(t,Vector3(.10,2,.10),Vector3(side*.85,1.15,0),steel)
	t.visual=Node3D.new();t.visual.name="Dummy";t.add_child(t.visual);t.visual.position.y=1.4
	var board=material(Color("82614c"),.3)
	box(t.visual,Vector3(1.3,1.55,.3),Vector3.ZERO,board)
	cylinder(t.visual,.32,.55,Vector3(0,1.02,0),board)
	box(t.visual,Vector3(1.6,.24,.35),Vector3(0,.62,0),steel)
	for radius in [.16,.35,.55]:
		var ring=MeshInstance3D.new();var mesh=TorusMesh.new();mesh.inner_radius=radius-.014;mesh.outer_radius=radius+.014;mesh.rings=32;mesh.ring_segments=8;ring.mesh=mesh;ring.material_override=paint;t.visual.add_child(ring);ring.position=Vector3(0,0,.165);ring.rotation.x=PI/2
	t.collider=StaticBody3D.new();t.collider.name="Hitbox";t.collider.collision_layer=2;t.collider.collision_mask=0;t.collider.set_meta("target",t);t.add_child(t.collider)
	var collision=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=Vector3(1.7,2.7,.45);collision.shape=shape;t.collider.add_child(collision);collision.position.y=1.6
	var health_root=Node3D.new();health_root.name="HealthRoot";t.add_child(health_root);health_root.position.y=3
	box(health_root,Vector3(1.65,.07,.07),Vector3.ZERO,dark)
	t.health=box(health_root,Vector3(1.6,.04,.08),Vector3(0,0,.005),gold).get_child(0);t.health.name="Health"
	floor_text("%02d"%(id+1),p+Vector3(0,.055,2.4),.02,80)
	for x in [-2.7,2.7]:box(self,Vector3(.06,.02,5),p+Vector3(x,.04,3),paint)
