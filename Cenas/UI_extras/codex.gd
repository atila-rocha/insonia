extends Control

signal fechado

@export var entradas: Array[EntradaCodex] = []

@onready var lista: VBoxContainer = %ListaEntradas
@onready var nome_label: Label = %NomeLabel
@onready var texto: RichTextLabel = %TextoDetalhe
@onready var botao_sair: Button = %BotaoSair

const COR_DESTAQUE := "#f0a030"
const COR_TITULO := "#a8b8c8"
const COR_SELECIONADO := Color("f0a030")
const ESTADOS_DE_COR := [
	"font_color",
	"font_hover_color",
	"font_focus_color",
	"font_pressed_color",
	"font_hover_pressed_color",
]

var _botao_selecionado: Button = null
var _botoes: Array[Button] = []


func _ready() -> void:
	botao_sair.pressed.connect(_fechar)
	_criar_lista()
	if _botoes.size() > 0:
		_botoes[0].grab_focus()
		_selecionar(entradas[0], _botoes[0])


func _criar_lista() -> void:
	for entrada in entradas:
		# Desbloqueio: a entrada só aparece depois de vencer a fase
		# (EstadoJogo.codex_desbloqueado). Antes disso fica "???".
		var botao := Button.new()
		botao.text = entrada.nome if _desbloqueada(entrada) else "???"
		botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
		botao.pressed.connect(_selecionar.bind(entrada, botao))
		lista.add_child(botao)
		_botoes.append(botao)
		
func _selecionar(entrada: EntradaCodex, botao: Button) -> void:
	_mostrar_entrada(entrada)
	_marcar_botao(botao)


func _marcar_botao(botao: Button) -> void:
	# Tira o laranja do botão que estava selecionado antes
	if _botao_selecionado != null:
		for estado in ESTADOS_DE_COR:
			_botao_selecionado.remove_theme_color_override(estado)

	# Aplica o laranja no novo botão em todos os estados
	_botao_selecionado = botao
	for estado in ESTADOS_DE_COR:
		botao.add_theme_color_override(estado, COR_SELECIONADO)


func _desbloqueada(entrada: EntradaCodex) -> bool:
	return entrada.id in EstadoJogo.codex_desbloqueado


func _mostrar_entrada(entrada: EntradaCodex) -> void:
	if not _desbloqueada(entrada):
		nome_label.text = "???"
		texto.text = "Ainda não descoberto.\n\nVença o perseguidor da fase para revelar esta entrada."
		return
	nome_label.text = entrada.nome
	texto.text = (
		"[color=%s]O QUE REPRESENTA[/color]\n%s\n\n"
		+ "[color=%s]COMPORTAMENTO[/color]\n%s\n\n"
		+ "[color=%s]FRAQUEZA[/color]\n%s"
	) % [
		COR_TITULO, entrada.representa,
		COR_TITULO, entrada.comportamento,
		COR_DESTAQUE, entrada.fraqueza
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fechar()


func _fechar() -> void:
	fechado.emit()
	queue_free()
