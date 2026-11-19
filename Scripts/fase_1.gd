extends Node2D
## Controla a cena jogável da Fase 1 (Biblioteca da UNIFOR):
## limites da câmera, buraco/água (volta ao último chão) e mensagem inicial.

@export var limites_camera: Rect2 = Rect2(0, 0, 2020, 830)
## Abaixo desta altura o Leo caiu num buraco (a água do mapa não tem chão).
@export var limite_queda_y: float = 870.0
@export var titulo: String = "Fase 1 · Biblioteca da UNIFOR"


func _ready() -> void:
	EstadoJogo.cena_fase_atual = scene_file_path
	_configurar_jogador.call_deferred()
	get_tree().call_group.call_deferred("hud", "clarear_tela", 0.8)
	get_tree().call_group.call_deferred("hud", "mostrar_mensagem", titulo + "\nEncontre a porta. Fuja da revoada.", 4.0)


func _configurar_jogador() -> void:
	var jogador := get_tree().get_first_node_in_group("jogador")
	if jogador == null:
		return
	jogador.set("limite_queda_y", limite_queda_y)
	var camera := jogador.get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.limit_left = int(limites_camera.position.x)
		camera.limit_top = int(limites_camera.position.y)
		camera.limit_right = int(limites_camera.end.x)
		camera.limit_bottom = int(limites_camera.end.y)
		camera.reset_smoothing()
