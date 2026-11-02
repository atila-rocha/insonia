extends Area2D

@export var dano: int = 15
@export var velocidade: float = 700.0
@export var gravidade: float = 500.0
@export var tempo_vida: float = 3.0

var direcao: float = 1.0
var usar_gravidade: bool = false
var velocidade_y: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	await get_tree().create_timer(tempo_vida).timeout
	queue_free()


func _process(delta: float) -> void:
	# Trajetória linear (lápis jogado no chão): só se move na horizontal.
	position.x += velocidade * direcao * delta

	# Trajetória de lançamento horizontal (lápis jogado no ar): mantém a
	# velocidade horizontal e acelera para baixo por causa da gravidade.
	if usar_gravidade:
		velocidade_y += gravidade * delta
		position.y += velocidade_y * delta

	var limites := get_viewport_rect().size
	if global_position.x < -50.0 or global_position.x > limites.x + 50.0 or global_position.y > limites.y + 200.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("inimigo") and body.has_method("recebe_dano"):
		body.recebe_dano(dano)
		queue_free()
