extends CanvasLayer
@onready var btn_continuar: Button = $Centro/Painel/Margem/Coluna/BotoesCima/BtnContinuar
@onready var btn_codex: Button = $Centro/Painel/Margem/Coluna/BotoesCima/BtnCodex
@onready var btn_config: Button = $Centro/Painel/Margem/Coluna/BotoesCima/btnConfig
@onready var btn_sair: Button = $Centro/Painel/Margem/Coluna/btnSair


func _ready() -> void:
	visible = false

	# Liga cada botão à sua ação
	btn_continuar.pressed.connect(fechar)
	btn_codex.pressed.connect(_ao_apertar_codex)
	btn_config.pressed.connect(_ao_apertar_config)
	btn_sair.pressed.connect(_ao_apertar_sair)

	for botao in [btn_continuar, btn_codex, btn_config, btn_sair]:
		botao.mouse_entered.connect(botao.grab_focus)  # mouse também seleciona

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pausar"):
		if visible:
			fechar()
		else:
			abrir()
		get_viewport().set_input_as_handled()


func abrir() -> void:
	visible = true
	get_tree().paused = true
	btn_continuar.grab_focus()  # começa selecionando "Continuar"


func fechar() -> void:
	visible = false
	get_tree().paused = false



func _ao_apertar_codex() -> void:
	pass  # PENDENTE: abrir a tela do Codex


func _ao_apertar_config() -> void:
	pass  # PENDENTE: abrir a tela de Configurações



func _ao_apertar_sair() -> void:
	get_tree().paused = false  # sempre despausar antes de trocar de cena
	get_tree().change_scene_to_file("res://Cenas/UI_extras/main_menu.tscn")
