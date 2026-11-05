extends Control

@onready var caixa: VBoxContainer = $MarginContainer/VBoxContainer
@onready var lua: TextureRect = $Moon

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
