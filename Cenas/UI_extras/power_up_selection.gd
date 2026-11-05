extends Control

# Aviso que o resto do jogo escuta para saber qual power-up foi escolhido
signal power_up_confirmado(dados: PowerUpData)

# Preenchidos no Inspector (passo 5)
@export var pool: Array[PowerUpData] = []
@export var cena_carta: PackedScene

@onready var cartas_box: HBoxContainer = %Cartas
@onready var nome_label: Label = %NomeLabel
@onready var descricao_label: Label = %DescricaoLabel
@onready var botao_confirmar: Button = %ConfirmarButton

var _grupo := ButtonGroup.new() # garante que só uma carta fique selecionada
var _cartas: Array[PowerUpCard] = []
var _escolhido: PowerUpData = null
var _confirmado := false


func _ready() -> void:
	botao_confirmar.disabled = true
	botao_confirmar.pressed.connect(_ao_confirmar)
	_criar_cartas(_sortear_dois())
	_mostrar(null)


# Embaralha a lista e pega os 2 primeiros: nunca repete
func _sortear_dois() -> Array[PowerUpData]:
	if pool.size() < 2:
		push_warning("O pool precisa ter pelo menos 2 power-ups.")
	var embaralhado := pool.duplicate()
	embaralhado.shuffle()
	var resultado: Array[PowerUpData] = []
	for i in mini(2, embaralhado.size()):
		resultado.append(embaralhado[i])
	return resultado


func _criar_cartas(lista: Array[PowerUpData]) -> void:
	for dados in lista:
		var carta: PowerUpCard = cena_carta.instantiate()
		carta.button_group = _grupo
		cartas_box.add_child(carta)
		carta.configurar(dados)
		carta.escolhido.connect(_ao_escolher)
		carta.mouse_sobre.connect(_mostrar)
		carta.mouse_saiu.connect(_ao_mouse_sair)
		_cartas.append(carta)


# Atualiza o painel. Se não receber nada, mostra a mensagem inicial.
func _mostrar(dados: PowerUpData) -> void:
	if dados == null:
		nome_label.text = "Escolha um power-up"
		descricao_label.text = "Passe o mouse sobre uma carta para ver os detalhes."
	else:
		nome_label.text = dados.nome
		descricao_label.text = dados.descricao


func _ao_mouse_sair() -> void:
	_mostrar(_escolhido) # volta a mostrar a carta selecionada (ou a mensagem inicial)


func _ao_escolher(dados: PowerUpData) -> void:
	_escolhido = dados
	botao_confirmar.disabled = false
	_mostrar(dados)


func _ao_confirmar() -> void:
	if _escolhido == null or _confirmado:
		return
	_confirmado = true
	botao_confirmar.disabled = true
	for carta in _cartas:
		carta.travar(carta.dados == _escolhido)
	nome_label.text = _escolhido.nome + " equipado!"
	power_up_confirmado.emit(_escolhido)
