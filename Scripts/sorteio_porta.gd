extends Node2D
## Porta sorteada (GDD, "Aleatoriedade"): os filhos Marker2D com nome
## começando em "Porta" são as posições possíveis. A cada entrada na fase,
## uma é sorteada com pick_random() e só ela recebe a porta.
## As portas desenhadas no TileMap pelo level design são apagadas, menos a
## de entrada (Marker2D chamado "Entrada"), para só existir uma porta ativa.

@export var cena_porta: PackedScene = preload("res://Cenas/Objetos/porta_fase.tscn")
@export var tilemap: TileMapLayer
## Id da fonte (atlas) da porta no TileSet da fase.
@export var fonte_tiles_porta: int = 10

var posicao_sorteada: Vector2


func _ready() -> void:
	var candidatos: Array[Marker2D] = []
	for filho in get_children():
		if filho is Marker2D and filho.name.begins_with("Porta"):
			candidatos.append(filho)
	if candidatos.is_empty():
		push_warning("SorteioPorta: nenhum Marker2D 'Porta...' encontrado.")
		return

	var escolhido: Marker2D = candidatos.pick_random()
	posicao_sorteada = escolhido.global_position
	print("Porta sorteada: ", escolhido.name)

	_apagar_portas_desenhadas()

	var porta := cena_porta.instantiate()
	add_child(porta)
	porta.global_position = posicao_sorteada


func _apagar_portas_desenhadas() -> void:
	if tilemap == null:
		return
	var entrada := get_node_or_null("Entrada") as Node2D
	for celula in tilemap.get_used_cells_by_id(fonte_tiles_porta):
		var pos := tilemap.to_global(tilemap.map_to_local(celula))
		if entrada and pos.distance_to(entrada.global_position) < 80.0:
			continue
		tilemap.erase_cell(celula)
