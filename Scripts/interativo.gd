class_name Interativo
extends Area2D
## Base para tudo que o Leo usa com a tecla E (banco, baú, porta).
## Quando o Leo entra na área, o objeto se registra no jogador; o jogador
## mostra a dica no HUD e chama interagir() ao apertar E.

## Texto mostrado no HUD quando o Leo está perto.
@export var dica: String = "[E] Interagir"


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # camada "Jogador"
	monitorable = false
	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)


func _ao_entrar(corpo: Node) -> void:
	if corpo.is_in_group("jogador") and corpo.has_method("adicionar_interativo"):
		corpo.adicionar_interativo(self)


func _ao_sair(corpo: Node) -> void:
	if corpo.is_in_group("jogador") and corpo.has_method("remover_interativo"):
		corpo.remover_interativo(self)


func texto_dica() -> String:
	return dica


## Sobrescrever nas cenas filhas.
func interagir(_jogador: Node) -> void:
	pass
