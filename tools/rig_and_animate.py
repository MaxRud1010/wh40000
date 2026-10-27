"""Bake the supplied, separated character into a Godot-ready skeletal GLB.
blender -b -t 6 -P tools/rig_and_animate.py
The original uploaded file is never changed.
"""
import bpy, math, os
from mathutils import Vector, Quaternion
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ROOT+'/assets/models/titus-separated.glb')
armor=bpy.data.objects.get('TitusArmor')
assert armor and armor.type=='MESH'
def point(p):
 x,y,z=p;return Vector((x/2.4,-(z+.34)/2.4,y/2.4))
# Skeleton in anatomical rest pose; all animation is exported as real bone tracks.
heads={'root':(0,0,-.34),'hip':(0,1.30,-.35),'spine':(0,1.65,-.38),'head':(0,2.07,-.37)}
parents={'hip':'root','spine':'hip','head':'spine'}
for side,sgn in [('R',-1),('L',1)]:
 heads.update({'arm'+side:(sgn*.50,1.94,-.36),'forearm'+side:(sgn*.62,1.60,-.22),'hand'+side:(sgn*.62,1.14,-.08),'thigh'+side:(sgn*.28,1.24,-.36),'shin'+side:(sgn*.39,.67,-.28),'foot'+side:(sgn*.40,.12,-.22)})
 parents.update({'arm'+side:'spine','forearm'+side:'arm'+side,'hand'+side:'forearm'+side,'thigh'+side:'hip','shin'+side:'thigh'+side,'foot'+side:'shin'+side})
arm_data=bpy.data.armatures.new('TitusSkeleton');arm=bpy.data.objects.new('TitusRig',arm_data);bpy.context.collection.objects.link(arm);bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for name,p in heads.items():
 b=arm_data.edit_bones.new(name);b.head=point(p)
 child=next((n for n,parent in parents.items() if parent==name),None)
 b.tail=point(heads[child]) if child else b.head+Vector((0,0,.065))
 if (b.tail-b.head).length<.01:b.tail=b.head+Vector((0,0,.1))
 if name in parents:b.parent=arm_data.edit_bones[parents[name]]
bpy.ops.object.mode_set(mode='OBJECT')
rest={n:arm_data.bones[n].matrix_local.to_quaternion() for n in heads}
for n in heads:armor.vertex_groups.new(name=n)
def smooth(v,a,b):
 t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
for vertex in armor.data.vertices:
 x,y,z=vertex.co.x*2.4,vertex.co.z*2.4,-vertex.co.y*2.4-.34;a=abs(x);side='R' if x<0 else 'L'
 arms=(a>.43 or a>.34 and y>1.78) and 1.02<y<2.16 and z>-.60
 if arms:
  if y<1.30:t=smooth(y,1.20,1.30);weights=[('hand'+side,1-t),('forearm'+side,t)]
  elif y<1.68:t=smooth(y,1.56,1.68);weights=[('forearm'+side,1-t),('arm'+side,t)]
  else:weights=[('arm'+side,1)]
 elif y<1.24 and a>.17:
  if y<.16:weights=[('foot'+side,1)]
  elif y<.73:t=smooth(y,.61,.73);weights=[('shin'+side,1-t),('thigh'+side,t)]
  else:t=smooth(y,1.16,1.24);weights=[('thigh'+side,1-t),('hip',t)]
 elif y>2 and a<.28 and z>-.60:
  t=smooth(y,2,2.08);weights=[('head',t),('spine',1-t)]
 else:t=smooth(y,1.36,1.50);weights=[('hip',1-t),('spine',t)]
 for name,w in weights:
  if w>0:armor.vertex_groups[name].add([vertex.index],w,'REPLACE')
modifier=armor.modifiers.new('Skeletal deformation','ARMATURE');modifier.object=arm;armor.parent=arm

def weapon(name,grip,direction,target):
 o=bpy.data.objects[name];grip=point(grip)
 # Input vectors are in glTF/model coordinates, Blender uses (x,-z,y).
 d=Vector((direction[0],-direction[2],direction[1])).normalized();t=Vector((target[0],-target[2],target[1])).normalized();q=d.rotation_difference(t)
 for v in o.data.vertices:v.co=q@(v.co-grip)
 o.data.update();return o,q,grip
bolt,q,grip=weapon('Bolter',(.63,1.11,-.16),(0,-.98,.12),(0,0,1))
bpy.ops.object.empty_add();muzzle=bpy.context.object;muzzle.name='Muzzle';muzzle.parent=bolt;muzzle.location=q@(point((.636,.68,-.11))-grip)
sword,q,grip=weapon('Chainsword',(-.555,1.12,-.035),(.37,-.22,.91),(0,1,0))
bpy.ops.object.empty_add();tip=bpy.context.object;tip.name='SwordTip';tip.parent=sword;tip.location=q@(point((-.19,.90,.88))-grip)

FPS=60
clips={'idle_bolter':2.4,'idle_sword':2.4,'walk_bolter':.80,'walk_sword':.80,'run_bolter':.58,'run_sword':.58,'aim_bolter':1.0,'fire_bolter':.22,'reload_bolter':2.1,'draw_bolter':1.05,'draw_sword':1.05,'sword_slash_left':.85,'sword_slash_right':.85,'sword_overhead':1.10}
LOOPS={'idle_bolter','idle_sword','walk_bolter','walk_sword','run_bolter','run_sword','aim_bolter'}
sc=bpy.context.scene;sc.render.fps=FPS;arm.animation_data_create()
def rot(name,rx=0,ry=0,rz=0):
 # Conjugation applies common model-space controls to anatomical rest axes.
 q=Quaternion((1,0,0),rx)@Quaternion((0,0,1),ry)@Quaternion((0,-1,0),rz)
 arm.pose.bones[name].rotation_quaternion=rest[name].inverted()@q@rest[name]
def move(name,x=0,y=0,z=0):arm.pose.bones[name].location=rest[name].inverted()@Vector((x,-z,y))
def lerp(a,b,t):return a+(b-a)*t
def ease(t):return smooth(t,0,1)
def ik_leg(side,foot_z,foot_y,hip_offset,roll=0):
 hip_y=1.24/2.4+hip_offset;hip_z=(-.36+.34)/2.4
 l1=math.hypot(.57,.08)/2.4;l2=math.hypot(.55,.06)/2.4
 dz=foot_z-hip_z;dy=foot_y-hip_y;d=min(math.hypot(dz,dy),l1+l2-.0002);d=max(d,.01)
 uz,uy=dz/math.hypot(dz,dy),dy/math.hypot(dz,dy);along=(l1*l1-l2*l2+d*d)/(2*d);h=math.sqrt(max(0,l1*l1-along*along))
 kz=hip_z+uz*along-uy*h;ky=hip_y+uy*along+uz*h
 a1=math.atan2(kz-hip_z,-(ky-hip_y));a2=math.atan2(foot_z-kz,-(foot_y-ky))
 thigh=math.atan2(.08,.57)-a1;shin=math.atan2(.06,.55)-a2-thigh
 rot('thigh'+side,thigh);rot('shin'+side,shin);rot('foot'+side,-thigh-shin+roll)

for name,duration in clips.items():
 action=bpy.data.actions.new(name);action.use_fake_user=True;arm.animation_data.action=action
 frames=max(2,round(duration*FPS));duration=frames/FPS
 for f in range(frames+1):
  t=f/frames;tm=t*duration
  for pb in arm.pose.bones:pb.rotation_mode='QUATERNION';pb.rotation_quaternion=(1,0,0,0);pb.location=(0,0,0)
  gun=not ('sword' in name and not name=='draw_bolter');hip_y=math.sin(tm*math.tau/2.4)*.0025;rot('spine',math.sin(tm*math.tau/2.4)*.004)
  ar=-.16 if gun else -.10;fr=-.84 if gun else -.18;hr=-ar-fr if gun else .05
  rot('armR',ar,0,.035);rot('forearmR',fr);rot('handR',hr)
  rot('armL',-.18 if gun else .03,0,-.12);rot('forearmL',-.5 if gun else -.10)
  if name.startswith(('walk','run')):
   run=name.startswith('run');duty=.43 if run else .65;speed=(6.4 if run else 3.0)/3.1;stride=speed*duration*duty
   hip_y=-.080+(math.cos(t*math.tau*2)*.025 if run else math.cos(t*math.tau*2)*.008)
   for side,offset in [('R',0),('L',.5)]:
    p=(t+offset)%1
    if p<duty:u=p/duty;fz=((- .36 + .34)/2.4)+lerp(stride/2,-stride/2,u);fy=.12/2.4;roll=.10*max(0,(u-.75)/.25)
    else:u=(p-duty)/(1-duty);fz=((- .36 + .34)/2.4)+lerp(-stride/2,stride/2,ease(u));fy=.12/2.4+math.sin(u*math.pi)**1.3*(.12 if run else .045);roll=-.13*math.sin(u*math.pi)
    ik_leg(side,fz,fy,hip_y,roll)
   wave=math.sin(t*math.tau);rot('spine',.18 if run else .045,-wave*.055,-wave*.025);rot('head',-.09 if run else -.025,wave*.035)
   if gun:ar=-.38-wave*.08;fr=-.75;rot('armR',ar,0,.04);rot('forearmR',fr);rot('handR',-ar-fr+.15)
   else:ar=-.12-wave*(.40 if run else .23);rot('armR',ar,0,.08);rot('forearmR',-.22);rot('handR',.10)
   rot('armL',.06+wave*(.45 if run else .25),0,-.08);rot('forearmL',-.22 if run else -.12)
  elif name in ['aim_bolter','fire_bolter']:
   recoil=math.exp(-t*7)*math.sin(t*math.pi) if name=='fire_bolter' else 0
   rot('spine',.035-recoil*.035,0,-.015);ar=-.52-recoil*.13;fr=-1.00-recoil*.06
   rot('armR',ar,0,.025);rot('forearmR',fr);rot('handR',-ar-fr-recoil*.07)
   rot('armL',-.48,0,-.46);rot('forearmL',-.9,0,-.18);rot('handL',1.35)
   hip_y=-.012;ik_leg('R',.05,.05,hip_y);ik_leg('L',.05,.05,hip_y)
  elif name.startswith('draw_'):
   reach=math.sin(min(1,t/.5)*math.pi/2) if t<.5 else math.cos((t-.5)*math.pi)
   rot('armR',-.16-reach*2.25,reach*.10,reach*.22);rot('forearmR',-.5-reach*.65);rot('handR',reach*.8);rot('spine',0,-reach*.15,-reach*.035);rot('head',0,-reach*.11)
   if t>.82:
    u=ease((t-.82)/.18);desired_ar=-.16 if name=='draw_bolter' else -.10;desired_fr=-.84 if name=='draw_bolter' else -.18
    rot('armR',lerp(-.16-reach*2.25,desired_ar,u));rot('forearmR',lerp(-.5-reach*.65,desired_fr,u));rot('handR',lerp(reach*.8,-desired_ar-desired_fr if name=='draw_bolter' else .05,u))
  elif name=='reload_bolter':
   u=math.sin(t*math.pi);rot('armR',-.30,0,.15);rot('forearmR',-.78);rot('handR',1.08,0,-.18*u);rot('armL',-.28-u*.35,0,-.5*u);rot('forearmL',-.45-u*.8);rot('handL',1.1*u);rot('head',.12*u,-.10*u);rot('spine',.025,0,-.02*u)
   move('forearmL',0,.008*math.sin(t*math.pi*5)*u,0)
  elif name.startswith('sword_'):
   overhead=name.endswith('overhead');right=name.endswith('right');sgn=-1 if right else 1
   # Anticipation, accelerated contact, follow-through and settled recovery.
   if t<.28:u=ease(t/.28);attack=0;recover=0
   elif t<.55:u=1;attack=ease((t-.28)/.27);recover=0
   else:u=1;attack=1;recover=ease((t-.55)/.45)
   if overhead:
    ar=lerp(-.10,-2.25,u);ar=lerp(ar,-.35,attack);ar=lerp(ar,-.10,recover)
    fr=lerp(-.18,-.8,u);fr=lerp(fr,-.20,attack);fr=lerp(fr,-.18,recover)
    hr=lerp(.05,-.1,u);hr=lerp(hr,.9,attack);hr=lerp(hr,.05,recover)
    rot('armR',ar,0,.10*math.sin(t*math.pi));rot('forearmR',fr);rot('handR',hr);rot('spine',lerp(-.12*u,.24,attack)*(1-recover),0,0)
   else:
    twist=sgn*(lerp(-.42*u,.38,attack))*(1-recover)
    ar=lerp(-.10,-1.35,u);ar=lerp(ar,-.25,attack);ar=lerp(ar,-.10,recover)
    rz=sgn*lerp(-.55*u,.8,attack)*(1-recover)
    rot('armR',ar,sgn*.3*math.sin(t*math.pi),rz);rot('forearmR',lerp(-.18,-.48,u)*(1-recover)-.18*recover);rot('handR',.1+.8*attack*(1-recover))
    rot('spine',.07*math.sin(t*math.pi),twist,-.06*sgn*math.sin(t*math.pi));rot('head',0,-twist*.45)
   hip_y=-.035-.025*math.sin(t*math.pi);move('hip',sgn*.013*math.sin(t*math.pi),hip_y,.025*math.sin(t*math.pi))
   ik_leg('R',.11,.05,hip_y);ik_leg('L',-.025,.05,hip_y)
   rot('armL',-.15-.5*math.sin(t*math.pi),0,-.12-.25*math.sin(t*math.pi));rot('forearmL',-.3)
  if not name.startswith('sword_'):move('hip',0,hip_y,0)
  for pb in arm.pose.bones:
   pb.keyframe_insert('rotation_quaternion',frame=f+1,group=pb.name);pb.keyframe_insert('location',frame=f+1,group=pb.name)
 for curve in action.fcurves:
  for key in curve.keyframe_points:key.interpolation='LINEAR'
 print('BAKED',name,frames+1,'frames',flush=True)
arm.animation_data.action=None
for pb in arm.pose.bones:pb.rotation_quaternion=(1,0,0,0);pb.location=(0,0,0)
for ob in bpy.context.scene.objects:ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/models/titus.glb',export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/tools/source/titus-rig.blend')
print('GODOT MODEL READY',flush=True)
