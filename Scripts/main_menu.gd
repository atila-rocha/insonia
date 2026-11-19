extends Control

@onready var caixa: VBoxContainer = $MarginContainer/VBoxContainer
@onready var lua: TextureRect = $Moon

const CENA_CODEX := preload("res://Cenas/UI_extras/codex.tscn")

@export var margem_lua: float = 12.0
var lua_x: float = 0.0

var botoes: Array[Button] = []

func _ready() -> void:
	# Junta todos os botões que estão dentro do VBoxContainer
	for filho in caixa.get_children():
		if filho is Button:
			botoes.append(filho)

	# Quando um botão recebe foco, a lua vai até ele
	for botao in botoes:
		botao.focus_entered.connect(_ao_focar.bind(botao))
		botao.mouse_entered.connect(botao.grab_focus)

	# Ação de cada botão (pelo texto que aparece na tela)
	for botao in botoes:
		match botao.text:
			"JOGAR":
				botao.pressed.connect(_ao_jogar)
			"INICIAR NOVO JOGO":
				botao.pressed.connect(_ao_novo_jogo)
			"CODEX":
				botao.pressed.connect(_ao_abrir_codex)
			"SAIR":
				botao.pressed.connect(get_tree().quit)

	# Espera 1 frame para o container calcular as posições
	await get_tree().process_frame
	lua_x = _calcular_x_lua()
	botoes[0].grab_focus()

func _largura_texto(botao: Button) -> float:
	var fonte: Font = botao.get_theme_font("font")
	var tamanho_fonte: int = botao.get_theme_font_size("font_size")
	return fonte.get_string_size(
		botao.text, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho_fonte
	).x

func _calcular_x_lua() -> float:
	# Encontra o ponto onde começa o texto mais largo do menu
	var x_mais_a_esquerda: float = INF
	for botao in botoes:
		var centro_x: float = botao.global_position.x + botao.size.x / 2.0
		var inicio_texto: float = centro_x - _largura_texto(botao) / 2.0
		x_mais_a_esquerda = min(x_mais_a_esquerda, inicio_texto)
	return x_mais_a_esquerda - lua.size.x - margem_lua

func _ao_focar(botao: Button) -> void:
	lua.global_position = Vector2(
		lua_x,
		botao.global_position.y + (botao.size.y - lua.size.y) / 2.0
	)


func _ao_jogar() -> void:
	get_tree().change_scene_to_file(EstadoJogo.cena_fase_atual)


func _ao_novo_jogo() -> void:
	EstadoJogo.novo_jogo()
	get_tree().change_scene_to_file(EstadoJogo.CENA_FASE_1)


func _ao_abrir_codex() -> void:
	var codex := CENA_CODEX.instantiate()
	add_child(codex)
	codex.fechado.connect(func() -> void: botoes[0].grab_focus())
