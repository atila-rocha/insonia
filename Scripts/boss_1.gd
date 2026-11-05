extends StaticBody2D

signal vida_alterada(atual: int, maxima: int)

@export var vida_maxima: int = 480
@export var velocidade: float = 100.0

## Limites de patrulha em coordenadas globais. Se ficarem em (0, 0)
## o inimigo usa automaticamente as bordas da tela.
@export var limite_esquerdo: float = 0.0
@export var limite_direito: float = 0.0

var vida: int
var direcao: float = 1.0


func _ready() -> void:
	add_to_group("inimigo")
	vida = vida_maxima
	vida_alterada.emit(vida, vida_maxima)

	if has_node("BarraVida"):
		$BarraVida.definir_vida_maxima(vida_maxima)

	if limite_direito <= limite_esquerdo:
		limite_esquerdo = 0.0
		limite_direito = get_viewport_rect().size.x

	if has_node("AreaDano"):
		$AreaDano.body_entered.connect(_on_area_dano_body_entered)


func _process(delta: float) -> void:
	position.x += velocidade * direcao * delta

	if direcao > 0.0 and global_position.x >= limite_direito:
		direcao = -1.0
		_atualizar_flip()
	elif direcao < 0.0 and global_position.x <= limite_esquerdo:
		direcao = 1.0
		_atualizar_flip()


func _atualizar_flip() -> void:
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = direcao < 0.0


func recebe_dano(dano: int) -> void:
	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)
	print("Vida inimigo: ", vida)

	if has_node("BarraVida"):
		$BarraVida.definir_vida(vida, vida_maxima)

	if vida <= 0:
		queue_free()


func _on_area_dano_body_entered(body: Node) -> void:
	if body.is_in_group("jogador") and body.has_method("receber_dano"):
		body.receber_dano(20)
