extends CharacterBody2D
## Formiga (GDD, "Inimigo Comum"): patrulha o chão de um lado para o outro,
## muda de direção ao bater em obstáculos (ou na beirada da plataforma),
## morre com um pulo em cima e tira 10% da sanidade no contato lateral.
##
## Máquina de estados simples: formigas usam apenas patrulha (+ morta).

enum Estado { PATRULHA, MORTA }

@export var velocidade: float = 45.0
## 1 = começa indo para a direita, -1 = esquerda.
@export_range(-1, 1, 2) var direcao_inicial: int = -1
@export var dano_contato: int = 10
## O sprite original da formiga olha para a esquerda.
@export var sprite_olha_para_direita: bool = false

var estado: Estado = Estado.PATRULHA
var direcao: float = -1.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _colisao: CollisionShape2D = $CollisionShape2D
@onready var _area_dano: Area2D = $AreaDano


func _ready() -> void:
	add_to_group("inimigo")
	direcao = float(direcao_inicial)
	_sprite.play("Andar")
	_atualizar_flip()


func _physics_process(delta: float) -> void:
	if estado == Estado.MORTA:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	velocity.x = direcao * velocidade
	move_and_slide()

	# Bateu numa parede ou chegou na beirada: vira para o outro lado.
	if is_on_floor() and (is_on_wall() or not _tem_chao_a_frente()):
		direcao = -direcao
		_atualizar_flip()

	_verificar_contato()


## Testa se existe chão logo à frente (evita a formiga cair da plataforma).
func _tem_chao_a_frente() -> bool:
	var largura: float = _colisao.shape.get_rect().size.x * 0.5 + 2.0
	var a_frente := global_transform.translated(Vector2(direcao * largura, 0.0))
	return test_move(a_frente, Vector2(0.0, 8.0))


func _atualizar_flip() -> void:
	var indo_para_direita := direcao > 0.0
	_sprite.flip_h = indo_para_direita != sprite_olha_para_direita


## Contato lateral com o Leo: -10% da barra. Se o Leo estiver vindo de cima,
## não causa dano (é o pulo que mata a formiga, tratado no jogador.gd).
func _verificar_contato() -> void:
	for corpo in _area_dano.get_overlapping_bodies():
		if not corpo.is_in_group("jogador") or not corpo.has_method("receber_dano"):
			continue
		if corpo.get("invencivel") == true or _jogador_esta_por_cima(corpo):
			continue
		corpo.receber_dano(dano_contato)
		# Depois de morder, a formiga dá meia-volta (não passa por baixo do Leo).
		direcao = -signf(corpo.global_position.x - global_position.x)
		_atualizar_flip()
		_sprite.play("Atacar")
		if not _sprite.animation_finished.is_connected(_voltar_a_andar):
			_sprite.animation_finished.connect(_voltar_a_andar, CONNECT_ONE_SHOT)


func _jogador_esta_por_cima(jogador: Node2D) -> bool:
	var topo_formiga := global_position.y - _colisao.shape.get_rect().size.y * 0.5
	var forma := jogador.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var pes_jogador := jogador.global_position.y
	if forma and forma.shape:
		pes_jogador = forma.global_position.y + forma.shape.get_rect().size.y * 0.5
	return pes_jogador <= topo_formiga + 6.0


func _voltar_a_andar() -> void:
	if estado == Estado.PATRULHA:
		_sprite.play("Andar")


## Chamado pelo jogador (pulo em cima) e pelo lápis.
func recebe_dano(_dano: int) -> void:
	if estado == Estado.MORTA:
		return
	estado = Estado.MORTA
	velocity = Vector2.ZERO
	remove_from_group("inimigo")
	_colisao.set_deferred("disabled", true)
	_area_dano.set_deferred("monitoring", false)
	_sprite.play("Morrer")

	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
