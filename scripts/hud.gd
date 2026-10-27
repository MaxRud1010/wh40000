extends Control
signal command(value)
const CREAM=Color("e8e4d4")
const MUTED=Color("98a28d")
const ORANGE=Color("dc8b47")
var regular=preload("res://assets/fonts/Interface.ttf")
var mono=preload("res://assets/fonts/Mono.ttf")
var bold=preload("res://assets/fonts/Heading.ttf")
var game
var toast=""
var toast_time=0.0
var help_open=false
var objectives=[false,false,false]
var buttons={}
var help_panel:Panel

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	_button("sound","ЗВУК ВЫКЛ.",Rect2(1360,28,130,38),func():command.emit("sound"))
	_button("help","?",Rect2(1520,28,42,38),func():toggle_help())
	_button("move","➤\nДВИЖЕНИЕ  [M]",Rect2(605,835,105,80),func():command.emit("move"))
	_button("attack","⌖\nАТАКА  [A]",Rect2(719,835,105,80),func():command.emit("attack"))
	_button("stop","■\nСТОП  [H]",Rect2(833,835,105,80),func():command.emit("stop"))
	_button("direct","◎\nКОНТРОЛЬ",Rect2(947,835,105,80),func():command.emit("direct"))
	_button("bolter","1   БОЛТЕР\n30 / ∞",Rect2(1100,824,215,112),func():command.emit("bolter"))
	_button("sword","2   ЦЕПНОЙ МЕЧ\nIII  КОМБО",Rect2(1325,824,215,112),func():command.emit("sword"))
	_button("reload","ПЕРЕЗАРЯДКА [R]",Rect2(1320,787,225,28),func():command.emit("reload"))
	_button("focus","К БОЙЦУ  [SPACE]",Rect2(870,928,180,24),func():command.emit("focus"))
	_button("reset","↻  СБРОСИТЬ ПОЛИГОН",Rect2(1060,966,270,25),func():command.emit("reset"))
	_make_help()

func _style(border:Color,bg:Color)->StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=bg;s.border_color=border;s.set_border_width_all(1);s.content_margin_left=9;s.content_margin_right=9
	return s

func _button(id:String,text:String,rect:Rect2,callback):
	var b=Button.new();b.text=text;b.position=rect.position;b.size=rect.size;b.add_theme_font_override("font",mono);b.add_theme_font_size_override("font_size",11);b.add_theme_color_override("font_color",CREAM)
	b.add_theme_stylebox_override("normal",_style(Color(.7,.78,.6,.2),Color(.12,.16,.13,.6)))
	b.add_theme_stylebox_override("hover",_style(Color(.8,.85,.65,.7),Color(.22,.28,.21,.9)))
	b.add_theme_stylebox_override("pressed",_style(ORANGE,Color(.32,.25,.16,.9)))
	b.pressed.connect(callback);add_child(b);buttons[id]=b

func _make_help():
	help_panel=Panel.new();help_panel.position=Vector2(450,130);help_panel.size=Vector2(700,680);help_panel.add_theme_stylebox_override("panel",_style(Color("7d8c6d"),Color("202a25")));add_child(help_panel);help_panel.visible=false
	var heading=Label.new();heading.text="КОМАНДУЙТЕ. ИСПОЛНЯЙТЕ.";heading.position=Vector2(35,30);heading.add_theme_font_override("font",bold);heading.add_theme_font_size_override("font_size",25);help_panel.add_child(heading)
	var text=Label.new();text.text="ЛКМ                         Выбрать Титуса\nПКМ                         Движение / атака мишени\nДвойной ПКМ                 Тяжёлый бег\nShift + ПКМ                 Очередь маршрутов\n1 / 2                       Болтер / цепной меч\nR / H                       Перезарядка / стоп\nCtrl                        Прямой контроль\nWASD + Shift                Двигаться / бежать в прямом режиме\nЛКМ в прямом режиме         Стрелять / бить мечом\nСтрелки                     Перемещать камеру\nЗажать СКМ                  Вращать и наклонять камеру\nКолесо / Пробел             Масштаб / к бойцу\nEsc                         Отмена / закрыть справочник\n\nМишени восстанавливаются через 8 секунд.\nТри удара мечом выполняются последовательно.\nПереключение оружия прерывается только после завершения.";text.position=Vector2(35,100);text.add_theme_font_override("font",mono);text.add_theme_font_size_override("font_size",13);text.add_theme_constant_override("line_spacing",11);help_panel.add_child(text)
	var close=Button.new();close.text="К ПОЛИГОНУ →";close.position=Vector2(35,605);close.size=Vector2(630,45);close.pressed.connect(toggle_help);help_panel.add_child(close)

func toggle_help():
	help_open=not help_open;help_panel.visible=help_open;queue_redraw()

func notify(text:String):toast=text;toast_time=3.0

func _text(at:Vector2,text:String,size=14,color=CREAM,font=null):
	draw_string(regular if font==null else font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _draw():
	if game==null or not is_instance_valid(game.actor):return
	var actor=game.actor
	draw_rect(Rect2(0,0,1600,94),Color(.07,.11,.10,.91))
	_text(Vector2(42,58),"✦",43,CREAM,bold)
	_text(Vector2(102,53),"Т И Т У С",32,CREAM,bold)
	_text(Vector2(105,76),"ИСПЫТАТЕЛЬНЫЙ ПОЛИГОН",9,MUTED,mono)
	draw_circle(Vector2(650,48),3,Color("b4c891"));_text(Vector2(665,52),"СИМУЛЯЦИЯ АКТИВНА   /   СЕКТОР 07",11,MUTED,mono)
	draw_line(Vector2(0,94),Vector2(1600,94),Color(.8,.85,.7,.13))
	draw_rect(Rect2(30,124,282,375),Color(.10,.15,.12,.55))
	_text(Vector2(44,145),"✦  ПРОТОКОЛ ОБУЧЕНИЯ / 001",11,Color("b0bba1"),mono)
	_text(Vector2(43,192),"Проверка боем.",32,CREAM,bold)
	_text(Vector2(44,222),"Воин познаётся в действии.",13,MUTED)
	_text(Vector2(44,244),"Испытайте оружие. Отдайте приказ.",13,MUTED)
	draw_line(Vector2(44,267),Vector2(88,267),Color("88947c"))
	var titles=["Отдайте приказ движения","Смените оружие","Поразите учебную мишень"]
	var hints=["ПКМ по земле","Клавиши 1 / 2","ПКМ по противнику"]
	for i in range(3):
		var y=302+i*58;draw_rect(Rect2(44,y-15,27,27),Color(.7,.8,.6,.35),false)
		_text(Vector2(49,y+4),"✓" if objectives[i] else "%02d"%(i+1),12,Color("becfa5") if objectives[i] else MUTED,mono)
		_text(Vector2(85,y),titles[i],13,Color("bdcca9") if objectives[i] else CREAM)
		_text(Vector2(85,y+20),hints[i],10,MUTED,mono)
	_text(Vector2(44,478),"●  СВОБОДНАЯ ТРЕНИРОВКА",10,MUTED,mono)
	_text(Vector2(1280,145),"ИМПЕРСКИЙ УЧЕБНЫЙ КОМПЛЕКС",10,MUTED,mono)
	_text(Vector2(1340,183),"БАСТИОН VII",25,CREAM,bold)
	_text(Vector2(1310,207),"56° 04′ N / 38° 12′ E",10,MUTED,mono)
	_text(Vector2(540,762),"ПКМ  ДВИЖЕНИЕ / АТАКА     2× ПКМ  БЕГ     SHIFT  ОЧЕРЕДЬ",10,CREAM,mono)
	for rect in [Rect2(28,785,230,174),Rect2(262,785,320,174),Rect2(586,785,486,174),Rect2(1076,785,480,174)]:
		draw_rect(rect,Color(.10,.15,.12,.96));draw_rect(rect,Color(.6,.7,.5,.3),false)
	_text(Vector2(40,807),"ТАКТИЧЕСКАЯ КАРТА / 07",10,MUTED,mono)
	_draw_map(Rect2(42,822,201,112))
	_text(Vector2(42,950),"КОНТАКТОВ: %d"%game.live_targets(),9,MUTED,mono)
	_text(Vector2(282,809),"АДЕПТУС АСТАРТЕС",10,MUTED,mono)
	_text(Vector2(282,850),"ТИТУС",30,CREAM,bold)
	_text(Vector2(283,876),"ПРИМАРИС · ВЕТЕРАН",11,MUTED,mono)
	draw_rect(Rect2(282,893,275,4),Color("adc592"));_text(Vector2(282,918),"ЗДОРОВЬЕ     1 000 / 1 000",10,MUTED,mono)
	_text(Vector2(283,946),"● "+actor.phase,10,Color("becfa5"),mono)
	_text(Vector2(606,808),"ПРИКАЗЫ",10,MUTED,mono)
	_text(Vector2(816,808),"ПРЯМОЙ КОНТРОЛЬ" if actor.direct else "ТАКТИЧЕСКИЙ РЕЖИМ",9,MUTED,mono)
	_text(Vector2(606,946),"ВЫБРАН 1 БОЕЦ" if actor.selected else "НЕТ ВЫБРАННЫХ БОЙЦОВ",9,MUTED,mono)
	_text(Vector2(1100,808),"ВООРУЖЕНИЕ",10,MUTED,mono)
	_text(Vector2(28,985),"ЕСТЬ ТОЛЬКО ДОЛГ.",10,MUTED,mono)
	_text(Vector2(380,985),"ПОРАЖЕНО %02d / ПОПАДАНИЙ %02d"%[game.kills,game.hits],10,MUTED,mono)
	_text(Vector2(1400,985),"GODOT / 0.2",10,MUTED,mono)
	if toast_time>0:
		var w=mini(780,int(mono.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)+44)
		draw_rect(Rect2((1600-w)/2.0,698,w,42),Color(.09,.14,.11,.96));draw_rect(Rect2((1600-w)/2.0,698,2,42),ORANGE)
		_text(Vector2((1600-w)/2.0+20,725),toast,13,CREAM,mono)
	if help_open:draw_rect(Rect2(0,0,1600,1000),Color(0,0,0,.35))

func _draw_map(rect:Rect2):
	draw_rect(rect,Color("19251e"));draw_rect(rect,Color("53684c"),false)
	var scale=rect.size/Vector2(66,56)
	for c in game.navigation.COVER:draw_rect(Rect2(rect.position+(c.position+Vector2(33,29))*scale,c.size*scale),Color("67745a"))
	for t in game.world.targets:
		if t.alive:draw_rect(Rect2(rect.position+(Vector2(t.position.x,t.position.z)+Vector2(33,29))*scale-Vector2.ONE*2,Vector2.ONE*4),Color("ba8054"))
	var point=rect.position+(Vector2(game.actor.position.x,game.actor.position.z)+Vector2(33,29))*scale
	draw_circle(point,4,Color("ccdcaa"));draw_arc(point,7,0,TAU,24,Color("cadba0"),1)

func blocks_world(point:Vector2)->bool:
	return help_open or point.y<95 or point.y>780 or Rect2(30,124,282,375).has_point(point)

func _process(delta):
	toast_time=maxf(0,toast_time-delta)
	if game!=null and is_instance_valid(game.actor):
		buttons.bolter.text="1   БОЛТЕР\n%s / ∞"%("··" if game.actor.action=="reload" else str(game.actor.ammo))
		for name in ["bolter","sword"]:
			buttons[name].add_theme_stylebox_override("normal",_style(ORANGE if game.actor.weapon==name else Color(.7,.78,.6,.2),Color(.25,.20,.13,.8) if game.actor.weapon==name else Color(.12,.16,.13,.6)))
	queue_redraw()
