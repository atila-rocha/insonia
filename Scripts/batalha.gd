extends Node2D
## Batalha da Fase 1 (GDD): luta direta com o perseguidor. Ao derrotá-lo:
## a porta é desbloqueada, o jogador escolhe um power-up, ganha um fragmento
## da liberdade, desbloqueia o Codex e acontece a conversa no banco.

@export var boss: Node
@export var barra_vida_boss: Control
@export var porta: Node2D
@export var cena_power_up: PackedScene = preload("res://Cenas/UI_extras/power_up_selection.tscn")
@export var limites_camera: Rect2 = Rect2(0, 0, 1152, 648)
## Entradas do Codex liberadas ao vencer esta batalha.
@export var codex_desbloquear: Array[StringName] = [&"pombo", &"formiga"]
## Conversa no banco depois da batalha (roteiro do João Victor: editar aqui
## pelo Inspetor). Uma fala por linha.
@export_multiline var falas: PackedStringArray = [
	"(Leo se senta no banco e respira fundo. A revoada pousa ao lado dele.)",
	"POMBOS: A gente não consegue parar de voar... cada pensamento puxa outro.",
	"LEO: É assim que eu fico com o projeto. Tudo ao mesmo tempo, o tempo todo.",
	"POMBOS: Quando você para e respira, a gente pousa. Não precisa resolver tudo agora.",
	"(Leo recebeu um Fragmento da Liberdade.)",
]

var _camada_final: CanvasLayer
var _texto_fala: Label
var _indice_fala := -1


func _ready() -> void:
	get_tree().call_group.call_deferred("hud", "clarear_tela", 0.6)
	get_tree().call_group.call_deferred("hud", "mostrar_mensagem", "A revoada te encurralou! Pule na cabeça dela quando pousar.", 3.5)
	_configurar_camera.call_deferred()

	var chefe = boss
	if chefe:
		chefe.vida_alterada.connect(_on_boss_vida_alterada)
		chefe.derrotado.connect(_on_boss_derrotado)
		var barra = barra_vida_boss
		if barra:
			barra.definir_vida_maxima(chefe.vida_maxima)


func _configurar_camera() -> void:
	var jogador := get_tree().get_first_node_in_group("jogador")
	var camera: Camera2D = null
	if jogador:
		camera = jogador.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = int(limites_camera.position.x)
	camera.limit_top = int(limites_camera.position.y)
	camera.limit_right = int(limites_camera.end.x)
	camera.limit_bottom = int(limites_camera.end.y)
	camera.reset_smoothing()


func _on_boss_vida_alterada(atual: int, maxima: int) -> void:
	var barra = barra_vida_boss
	if barra:
		barra.definir_vida(atual, maxima)


func _on_boss_derrotado() -> void:
	for id in codex_desbloquear:
		EstadoJogo.desbloquear_codex(id)
	EstadoJogo.fragmentos += 1
	get_tree().call_group("hud", "mostrar_mensagem", "A porta foi desbloqueada!", 2.0)
	if porta and porta.has_node("Brilho"):
		porta.get_node("Brilho").set("energy", 1.4)

	await get_tree().create_timer(2.0).timeout
	_mostrar_power_ups()


func _mostrar_power_ups() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 8
	add_child(camada)
	var selecao = cena_power_up.instantiate()
	camada.add_child(selecao)
	selecao.power_up_confirmado.connect(_on_power_up_confirmado.bind(camada))


func _on_power_up_confirmado(dados: PowerUpData, camada: CanvasLayer) -> void:
	if not dados.id in EstadoJogo.power_ups:
		EstadoJogo.power_ups.append(dados.id)
	if dados.id == &"food":
		EstadoJogo.comidas += 1
	await get_tree().create_timer(1.2).timeout
	camada.queue_free()
	_comecar_conversa()


# ---------------- Conversa no banco (cutscene simples) ----------------

func _comecar_conversa() -> void:
	_camada_final = CanvasLayer.new()
	_camada_final.layer = 9
	add_child(_camada_final)

	var fundo := ColorRect.new()
	fundo.color = Color(0.03, 0.03, 0.05, 0.0)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_camada_final.add_child(fundo)
	create_tween().tween_property(fundo, "color:a", 1.0, 1.0)

	_texto_fala = Label.new()
	_texto_fala.add_theme_font_override("font", preload("res://Assets/Fonts/Pixelify_Sans/static/PixelifySans-Bold.ttf"))
	_texto_fala.add_theme_font_size_override("font_size", 24)
	_texto_fala.add_theme_color_override("font_color", Color("FFC27A"))
	_texto_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto_fala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_fala.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_fala.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texto_fala.offset_left = 120
	_texto_fala.offset_right = -120
	_camada_final.add_child(_texto_fala)

	var dica := Label.new()
	dica.text = "[E] / [Espaço] continuar"
	dica.add_theme_font_size_override("font_size", 14)
	dica.add_theme_color_override("font_color", Color("8b8fa0"))
	dica.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	dica.offset_top = -50
	dica.offset_left = -150
	dica.offset_right = 150
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camada_final.add_child(dica)

	var jogador := get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.set_physics_process(false)
		jogador.set_process_unhandled_input(false)

	await get_tree().create_timer(1.0).timeout
	_proxima_fala()


func _unhandled_input(event: InputEvent) -> void:
	if _indice_fala < 0:
		return
	if event.is_action_pressed("interagir") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_proxima_fala()


func _proxima_fala() -> void:
	_indice_fala += 1
	if _indice_fala < falas.size():
		_texto_fala.text = falas[_indice_fala]
		return
	if _indice_fala == falas.size():
		_texto_fala.text = "FASE 1 CONCLUÍDA\n\nFragmentos da liberdade: %d" % EstadoJogo.fragmentos
		return
	# Fase 2 ainda não existe: volta ao menu principal.
	_indice_fala = -1
	get_tree().change_scene_to_file(EstadoJogo.CENA_MENU)
