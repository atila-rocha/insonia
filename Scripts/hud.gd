extends CanvasLayer

## HUD de jogo. Escuta o jogador pelo grupo para continuar funcionando mesmo
## quando a cena do personagem for trocada.
@export var quantidade_comida: int = 3

@onready var barra_vida: Control = $Interface/Vida/BarraVida
@onready var texto_comida: Label = $Interface/Comida/Quantidade

var _jogador: Node


func _ready() -> void:
	texto_comida.text = "COMIDA: x%d" % quantidade_comida
	call_deferred("conectar_jogador")


func conectar_jogador() -> void:
	var jogadores := get_tree().get_nodes_in_group("jogador")
	if jogadores.is_empty():
		return

	_jogador = jogadores.front()
	if _jogador.has_signal("vida_alterada"):
		_jogador.vida_alterada.connect(_ao_alterar_vida)

	var maxima: int = _jogador.obter_vida_maxima() if _jogador.has_method("obter_vida_maxima") else 100
	var atual: int = _jogador.get("vida") if _jogador.get("vida") != null else maxima
	_ao_alterar_vida(atual, maxima)


func _ao_alterar_vida(atual: int, maxima: int) -> void:
	barra_vida.definir_vida(atual, maxima)


func definir_comida(quantidade: int) -> void:
	quantidade_comida = max(quantidade, 0)
	texto_comida.text = "COMIDA: x%d" % quantidade_comida
