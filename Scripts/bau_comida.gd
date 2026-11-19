extends Interativo
## Ponto de comida (GDD: "Interação com animais e comida"). Ao interagir, o
## Leo ganha comida, que faz o perseguidor parar para comer (tecla F).
## Enquanto não houver sprites de gato/cachorro, os baús do mapa fazem esse papel.

@export var quantidade: int = 1

var _usado := false


func _ready() -> void:
	super()
	dica = "[E] Pegar comida"


func texto_dica() -> String:
	return "Vazio" if _usado else dica


func interagir(jogador: Node) -> void:
	if _usado:
		return
	_usado = true
	if jogador.has_method("ganhar_comida"):
		jogador.ganhar_comida(quantidade)
	get_tree().call_group("hud", "mostrar_mensagem", "+%d comida  ·  [F] para soltar" % quantidade)
