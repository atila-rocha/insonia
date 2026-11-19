extends Node2D
## Comida solta pelo Leo (tecla F). Todo perseguidor por perto para de
## persegui-lo e vem comer (estado COMENDO da máquina de estados).

@export var alcance: float = 700.0
@export var duracao: float = 4.0


func _ready() -> void:
	# Espera 1 frame: quem cria a comida define a posição logo depois do add_child.
	_avisar_perseguidores.call_deferred()

	var tween := create_tween()
	tween.tween_interval(duracao + 0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func _avisar_perseguidores() -> void:
	for perseguidor in get_tree().get_nodes_in_group("perseguidor"):
		if perseguidor.has_method("distrair") and global_position.distance_to(perseguidor.global_position) <= alcance:
			perseguidor.distrair(global_position, duracao)
