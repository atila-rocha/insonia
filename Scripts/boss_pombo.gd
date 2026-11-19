extends CharacterBody2D
## Chefe da Fase 1: a revoada vira um pombo gigante (GDD, "Batalha contra o
## Perseguidor"). Para derrotá-lo, o Leo pula várias vezes na cabeça dele,
## como nos chefes de Super Mario. O lápis também causa dano.
##
## Máquina de estados (enum + match):
##   VOANDO      -> paira no alto, seguindo o Leo na horizontal (fora de alcance)
##   PREPARANDO  -> pisca e marca a posição do Leo (aviso do ataque)
##   MERGULHANDO -> desce em linha reta até o chão
##   NO_CHAO     -> fica bicando o chão (não machuca): hora de pular na cabeça dele
##   SUBINDO     -> volta para o alto
## Quanto menos vida, mais rápido e menos tempo ele fica no chão.

signal vida_alterada(atual: int, maxima: int)
signal derrotado

enum Estado { VOANDO, PREPARANDO, MERGULHANDO, NO_CHAO, SUBINDO, DERROTADO }

@export var vida_maxima: int = 40
@export var altura_voo: float = 140.0
@export var velocidade_voo: float = 140.0
@export var velocidade_mergulho: float = 520.0
@export var velocidade_subida: float = 220.0
@export var tempo_voando: Vector2 = Vector2(2.0, 3.5)
@export var tempo_preparando: float = 0.7
@export var tempo_no_chao: float = 2.2
@export var dano_contato: int = 20
## O sprite do pombo olha para a direita.
@export var sprite_olha_para_direita: bool = true

var vida: int
var estado: Estado = Estado.VOANDO
var _alvo: Node2D
var _destino: Vector2
var _timer: float = 0.0
var _tempo_total: float = 0.0
var _invencivel: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _area_dano: Area2D = $AreaDano
@onready var _colisao: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("inimigo")
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	vida = vida_maxima
	vida_alterada.emit(vida, vida_maxima)
	_timer = randf_range(tempo_voando.x, tempo_voando.y)
	_sprite.play("voar")


func _physics_process(delta: float) -> void:
	_tempo_total += delta
	if _alvo == null or not is_instance_valid(_alvo):
		_alvo = get_tree().get_first_node_in_group("jogador") as Node2D

	match estado:
		Estado.VOANDO:
			_voar(delta)
		Estado.PREPARANDO:
			_preparar(delta)
		Estado.MERGULHANDO:
			_mergulhar()
		Estado.NO_CHAO:
			_ficar_no_chao(delta)
		Estado.SUBINDO:
			_subir()
		Estado.DERROTADO:
			velocity = Vector2.ZERO

	move_and_slide()
	_verificar_contato()
	_atualizar_flip()


# ---------------- Estados ----------------

func _voar(delta: float) -> void:
	var alvo_x := _alvo.global_position.x if _alvo else global_position.x
	var dx := alvo_x - global_position.x
	velocity.x = clampf(dx, -1.0, 1.0) * _velocidade(velocidade_voo) if absf(dx) > 10.0 else 0.0
	# Balanço suave para cima e para baixo (seno), para parecer que está voando.
	velocity.y = (altura_voo + sin(_tempo_total * 3.0) * 12.0 - global_position.y) * 3.0
	_timer -= delta
	if _timer <= 0.0 and _alvo:
		_mudar_estado(Estado.PREPARANDO)


func _preparar(delta: float) -> void:
	velocity = Vector2.ZERO
	# Pisca em vermelho: aviso de que vai mergulhar.
	_sprite.modulate = Color(1, 0.45, 0.45) if int(_timer * 12.0) % 2 == 0 else Color.WHITE
	_timer -= delta
	if _timer <= 0.0:
		_sprite.modulate = Color.WHITE
		_mudar_estado(Estado.MERGULHANDO)


func _mergulhar() -> void:
	velocity = global_position.direction_to(_destino) * _velocidade(velocidade_mergulho)
	if is_on_floor() or get_slide_collision_count() > 0 or global_position.distance_to(_destino) < 12.0:
		_mudar_estado(Estado.NO_CHAO)


func _ficar_no_chao(delta: float) -> void:
	velocity = Vector2(0.0, 300.0)  # encostado no chão
	_timer -= delta
	if _timer <= 0.0:
		_mudar_estado(Estado.SUBINDO)


func _subir() -> void:
	velocity = Vector2(0.0, -_velocidade(velocidade_subida))
	if global_position.y <= altura_voo:
		_mudar_estado(Estado.VOANDO)


func _mudar_estado(novo: Estado) -> void:
	estado = novo
	match novo:
		Estado.VOANDO:
			_invencivel = false
			collision_layer = 4  # camada "Inimigos"
			_timer = randf_range(tempo_voando.x, tempo_voando.y) * _fator_raiva_tempo()
			_sprite.play("voar")
		Estado.PREPARANDO:
			_timer = tempo_preparando
			# Marca o ponto onde o Leo está agora, um pouco acima dos pés.
			_destino = _alvo.global_position + Vector2(0.0, 20.0) if _alvo else global_position
		Estado.MERGULHANDO:
			_sprite.play("voar")
		Estado.NO_CHAO:
			_timer = tempo_no_chao * _fator_raiva_tempo()
			_sprite.play("comer")
		Estado.SUBINDO:
			_sprite.play("voar")


## Com menos vida, o chefe fica mais rápido (sanidade do chefe "acelerada").
func _velocidade(base: float) -> float:
	return base * lerpf(1.4, 1.0, float(vida) / float(vida_maxima))


func _fator_raiva_tempo() -> float:
	return lerpf(0.6, 1.0, float(vida) / float(vida_maxima))


# ---------------- Dano ----------------

## Chamado pelo jogador (pulo na cabeça) e pelo lápis.
func recebe_dano(dano: int) -> void:
	if _invencivel or estado == Estado.DERROTADO:
		return
	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)
	print("Vida do boss: ", vida)

	if vida <= 0:
		_derrotar()
		return

	# Levou dano: pisca e foge para o alto. Fica invencível até voltar a
	# voar, para o Leo não emendar vários pulos seguidos no mesmo pouso.
	_invencivel = true
	# Sem colisão com o Leo enquanto sobe: ele não "pega carona" nas costas.
	collision_layer = 0
	var tween := create_tween()
	tween.set_loops(4)
	tween.tween_property(_sprite, "modulate:a", 0.3, 0.06)
	tween.tween_property(_sprite, "modulate:a", 1.0, 0.06)
	_mudar_estado(Estado.SUBINDO)


func _derrotar() -> void:
	_mudar_estado(Estado.DERROTADO)
	_sprite.play("comer")
	remove_from_group("inimigo")
	_colisao.set_deferred("disabled", true)
	_area_dano.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", global_position.y + 40.0, 0.6)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 1.2)
	tween.tween_callback(func() -> void: derrotado.emit())


func _verificar_contato() -> void:
	# Pousado e bicando o chão ele não machuca: é a janela para pular na cabeça.
	if estado == Estado.DERROTADO or estado == Estado.NO_CHAO:
		return
	for corpo in _area_dano.get_overlapping_bodies():
		if not corpo.is_in_group("jogador") or not corpo.has_method("receber_dano"):
			continue
		if corpo.get("invencivel") == true or _jogador_esta_por_cima(corpo):
			continue
		corpo.receber_dano(dano_contato)


func _jogador_esta_por_cima(jogador: Node2D) -> bool:
	var topo := _colisao.global_position.y - _colisao.shape.get_rect().size.y * 0.5 * absf(scale.y)
	var forma := jogador.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var pes := jogador.global_position.y
	if forma and forma.shape:
		pes = forma.global_position.y + forma.shape.get_rect().size.y * 0.5
	return pes <= topo + 10.0


func _atualizar_flip() -> void:
	if absf(velocity.x) < 1.0 or estado == Estado.DERROTADO:
		return
	var indo_para_direita := velocity.x > 0.0
	_sprite.flip_h = indo_para_direita != sprite_olha_para_direita
