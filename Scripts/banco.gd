extends Interativo
## Safe zone (GDD): banco sob a luz de um poste branco. Sentado, o Leo fica
## invisível ao perseguidor, respira calmamente e recupera sanidade.


func _ready() -> void:
	super()
	dica = "[E] Sentar no banco"


func interagir(jogador: Node) -> void:
	if jogador.has_method("sentar"):
		jogador.sentar()
