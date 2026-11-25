extends AnimatableBody2D

signal vida_alterada(atual: int, maxima: int)

enum Estado { PATRULHANDO, PREPARANDO_ATAQUE, ATACANDO }

@export var vida_maxima: int = 250

@export var velocidade_patrulha: float = 110.0

## Limites de patrulha em coordenadas globais. Se ficarem em (0, 0)
## o boss usa automaticamente as bordas da tela.
@export var limite_esquerdo: float = 0.0
@export var limite_direito: float = 0.0

@export var dano_contato: int = 15
@export var dano_ataque: int = 25

## Altura do arco do pulo do bote — "pular mais" fica aqui, bem visível.
@export var altura_salto: float = 130.0

## Quanto tempo o gato fica parado avisando o bote (tocando a animação de
## ataque, mas sem se mover ainda) — a janela que o jogador tem pra reagir.
@export var duracao_preparacao: float = 0.5

## Quanto tempo o salto inteiro dura, do chão até pousar de novo no chão.
@export var duracao_ataque: float = 0.7

@export var tempo_minimo_para_atacar: float = 4.0
@export var tempo_maximo_para_atacar: float = 8.0

# Tempo pequeno de "imunidade" logo depois de levar um dano.
const DURACAO_INVENCIVEL_DANO = 0.25

var vida: int
var direcao: float = 1.0
var estado: Estado = Estado.PATRULHANDO
var invencivel_a_dano: bool = false
var _tempo_no_estado: float = 0.0
var _jogador_alvo = null
var _origem_ataque: Vector2
var _alvo_ataque_x: float

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _colisao_solida: CollisionShape2D = $CollisionShape2D


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

	_sprite.play("run")
	_agendar_proximo_ataque()


func _physics_process(delta: float) -> void:
	match estado:
		Estado.PATRULHANDO:
			_mover_com_quique(velocidade_patrulha, delta)
		Estado.PREPARANDO_ATAQUE:
			pass  # trava no lugar avisando o bote, só esperando o timer
		Estado.ATACANDO:
			_tempo_no_estado += delta
			var t := clampf(_tempo_no_estado / duracao_ataque, 0.0, 1.0)

			# Arco de pulo: avança em X do início até o alvo, e em Y sobe e
			# desce como um seno (0 no início/fim, pico no meio) — um bote
			# saltado de verdade, pousando no chão em cima do alvo.
			var x := lerpf(_origem_ataque.x, _alvo_ataque_x, t)
			var altura := sin(t * PI) * altura_salto
			global_position = Vector2(x, _origem_ataque.y - altura)

			if t >= 1.0:
				_terminar_ataque()


func _mover_com_quique(velocidade: float, delta: float) -> void:
	position.x += velocidade * direcao * delta

	if direcao > 0.0 and global_position.x >= limite_direito:
		direcao = -1.0
		_atualizar_flip()
	elif direcao < 0.0 and global_position.x <= limite_esquerdo:
		direcao = 1.0
		_atualizar_flip()


func _atualizar_flip() -> void:
	_sprite.flip_h = direcao < 0.0


# Sorteia quanto tempo falta até o próximo bote. Um intervalo de 4 a 8
# segundos mistura bem com os outros bosses — nem spam de ataque, nem gato
# parado andando de um lado pro outro por tempo demais.
func _agendar_proximo_ataque() -> void:
	var espera := randf_range(tempo_minimo_para_atacar, tempo_maximo_para_atacar)
	get_tree().create_timer(espera).timeout.connect(_iniciar_ataque)


func _iniciar_ataque() -> void:
	if estado != Estado.PATRULHANDO:
		return

	_jogador_alvo = get_tree().get_first_node_in_group("jogador")
	if _jogador_alvo == null:
		_agendar_proximo_ataque()
		return

	estado = Estado.PREPARANDO_ATAQUE
	_sprite.play("attack")
	get_tree().create_timer(duracao_preparacao).timeout.connect(_comecar_ataque_de_verdade)


func _comecar_ataque_de_verdade() -> void:
	if estado != Estado.PREPARANDO_ATAQUE:
		return  # o boss pode ter morrido ou sido interrompido nesse meio tempo

	# O destino do pulo é travado NESTE instante (posição atual do jogador),
	# não perseguido depois — igual aprendemos com o boss_2: perseguir o
	# tempo todo torna o ataque impossível de desviar.
	var posicao_real_jogador: Vector2 = _jogador_alvo.global_position
	if _jogador_alvo.has_node("AnimatedSprite2D"):
		posicao_real_jogador = _jogador_alvo.get_node("AnimatedSprite2D").global_position

	_origem_ataque = global_position
	_alvo_ataque_x = posicao_real_jogador.x

	var diferenca_x := _alvo_ataque_x - _origem_ataque.x
	direcao = signf(diferenca_x) if diferenca_x != 0.0 else direcao
	_atualizar_flip()

	estado = Estado.ATACANDO
	_tempo_no_estado = 0.0

	# Desliga o corpo sólido durante o salto — senão ele esbarra no jogador
	# no meio do caminho (vira uma "parede") e trava antes de pousar em cima
	# dele. O dano continua valendo, porque a AreaDano é um nó separado.
	_colisao_solida.disabled = true


func _terminar_ataque() -> void:
	estado = Estado.PATRULHANDO
	_colisao_solida.disabled = false
	_sprite.play("run")
	_agendar_proximo_ataque()


func recebe_dano(dano: int) -> void:
	if invencivel_a_dano:
		return

	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)
	print("Vida do boss (gato): ", vida)

	if has_node("BarraVida"):
		$BarraVida.definir_vida(vida, vida_maxima)

	if vida <= 0:
		queue_free()
		return

	_ativar_invencibilidade_dano()


func _ativar_invencibilidade_dano() -> void:
	invencivel_a_dano = true

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.4, 0.08)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)

	await get_tree().create_timer(DURACAO_INVENCIVEL_DANO).timeout
	invencivel_a_dano = false


func _on_area_dano_body_entered(body: Node) -> void:
	if body.is_in_group("jogador") and body.has_method("receber_dano"):
		var dano := dano_ataque if estado == Estado.ATACANDO else dano_contato
		body.receber_dano(dano)
