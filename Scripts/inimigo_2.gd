extends StaticBody2D

# Exemplo de um TIPO DIFERENTE de inimigo (parado, não patrulha) para
# mostrar que a barra de vida (BarraVida) não é exclusiva do inimigo_1 —
# qualquer script que siga a mesma receita funciona com ela:
#   1. tiver um filho chamado "BarraVida" (instância de barra_vida_inimigo.tscn)
#   2. chamar $BarraVida.definir_vida_maxima(...) no _ready()
#   3. chamar $BarraVida.definir_vida(...) sempre que a vida mudar

signal vida_alterada(atual: int, maxima: int)

@export var vida_maxima: int = 30

var vida: int


func _ready() -> void:
	add_to_group("inimigo")
	vida = vida_maxima
	vida_alterada.emit(vida, vida_maxima)

	if has_node("BarraVida"):
		$BarraVida.definir_vida_maxima(vida_maxima)

	if has_node("AreaDano"):
		$AreaDano.body_entered.connect(_on_area_dano_body_entered)


func recebe_dano(dano: int) -> void:
	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)
	print("Vida inimigo_2: ", vida)

	if has_node("BarraVida"):
		$BarraVida.definir_vida(vida, vida_maxima)

	if vida <= 0:
		queue_free()


func _on_area_dano_body_entered(body: Node) -> void:
	if body.is_in_group("jogador") and body.has_method("receber_dano"):
		body.receber_dano(20)
