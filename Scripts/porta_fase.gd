extends Interativo
## Porta sorteada (GDD): leva à batalha direta com o perseguidor da fase.

@export_file("*.tscn") var cena_batalha: String = "res://Cenas/Fase_1/batalha_pombo.tscn"

var _entrando := false


func _ready() -> void:
	super()
	dica = "[E] Entrar na porta"


func interagir(jogador: Node) -> void:
	if _entrando or cena_batalha.is_empty():
		return
	_entrando = true
	jogador.set_physics_process(false)
	get_tree().call_group("hud", "escurecer_tela", 0.6)
	await get_tree().create_timer(0.7).timeout
	get_tree().change_scene_to_file(cena_batalha)
