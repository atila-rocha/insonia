extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -530.0
const VIDA_MAXIMA = 100
const COOLDOWN_ARREMESSO = 1.5
const DANO_PULO = 8

# Bit da camada de física "Inimigos" (ver Projeto > Configurações do Projeto
# > Camadas de Física 2D). Usado para tirar o jogador da detecção de
# inimigos durante a invencibilidade, sem afastá-lo do chão.
const CAMADA_INIMIGOS = 4

# Quanto tempo o jogador fica "imune" depois de levar um dano, para não
# tomar vários hits seguidos ficando encostado no inimigo (igual ao Mario
# piscando depois de ser atingido).
const DURACAO_INVENCIVEL = 1.0

@export var cena_lapis: PackedScene = preload("res://Cenas/Habilidades/lapis.tscn")
@export var velocidade_lancamento_vertical: float = 650.0

## Deslocamento (local, em pixels) do centro do sprite até a mão levantada
## na animação "arremesso_vertical" — é de onde o lápis sai nesse arremesso.
## O X é espelhado conforme o lado que o jogador está olhando.
@export var offset_mao_vertical: Vector2 = Vector2(10.0, -45.0)

## O sprite de "arremesso_vertical" vem de um canvas bem mais alto (466px)
## que os outros (idle/pulo/corrida, ~214-304px). Como o AnimatedSprite2D
## usa uma escala só para todas as animações, sem isso o personagem ficava
## enorme ao jogar pra cima. Essa escala é aplicada só durante essa animação.
@export var escala_arremesso_vertical: Vector2 = Vector2(0.19, 0.14)

var vida: int = VIDA_MAXIMA
var direcao_olhando: float = 1.0
var ultimo_arremesso_tempo: float = -COOLDOWN_ARREMESSO
var invencivel: bool = false
var _camada_colisao_original: int
var _mascara_colisao_original: int

# Enquanto uma animação de ação (ex.: o arremesso vertical) está tocando,
# a troca automática de idle/run/jump fica pausada até ela terminar.
var _acao_em_andamento: bool = false
var _escala_normal: Vector2

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("jogador")
	_camada_colisao_original = collision_layer
	_mascara_colisao_original = collision_mask
	_escala_normal = _sprite.scale

	if has_node("BarraVida"):
		$BarraVida.definir_vida_maxima(VIDA_MAXIMA)


func _physics_process(delta: float) -> void:
	# Guarda se já estava caindo antes deste frame, para saber depois do
	# move_and_slide() se o que aconteceu foi um "pulo em cima" do inimigo.
	var estava_caindo := velocity.y > 0.0

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		direcao_olhando = sign(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if estava_caindo:
		_verificar_pulo_em_inimigo()

	_atualizar_animacao()


func _atualizar_animacao() -> void:
	if _acao_em_andamento:
		return  # não interrompe a animação de ação (ex.: arremesso) em andamento

	_sprite.flip_h = direcao_olhando < 0.0

	if not is_on_floor():
		_tocar_animacao("jump")
	elif velocity.x != 0.0:
		_tocar_animacao("run")
	else:
		_tocar_animacao("idle")


func _tocar_animacao(nome: String) -> void:
	var animacao_alvo := nome

	# "run" ainda não tem frames importados. Sem isso, ao pousar andando o
	# pedido de trocar pra "run" falhava em silêncio e o sprite ficava
	# travado no último frame do pulo (parecendo agachado/pulando parado).
	# Cai pra "idle" nesse caso, em vez de simplesmente não trocar nada.
	if _sprite.sprite_frames and _sprite.sprite_frames.get_frame_count(animacao_alvo) == 0:
		animacao_alvo = "idle"

	if _sprite.animation == animacao_alvo:
		return

	if _sprite.sprite_frames and _sprite.sprite_frames.get_frame_count(animacao_alvo) == 0:
		return

	_sprite.play(animacao_alvo)


# Toca uma animação de ação (que não deve ser interrompida pelo idle/run/jump
# até terminar sozinha) — usada no arremesso vertical.
func _tocar_animacao_acao(nome: String) -> void:
	if _sprite.sprite_frames == null or _sprite.sprite_frames.get_frame_count(nome) == 0:
		return

	_acao_em_andamento = true

	if nome == "arremesso_vertical":
		_sprite.scale = escala_arremesso_vertical

	_sprite.play(nome)
	_sprite.animation_finished.connect(_on_animacao_acao_concluida, CONNECT_ONE_SHOT)


func _on_animacao_acao_concluida() -> void:
	_acao_em_andamento = false
	_sprite.scale = _escala_normal


func _verificar_pulo_em_inimigo() -> void:
	for i in get_slide_collision_count():
		var colisao := get_slide_collision(i)
		var corpo := colisao.get_collider()

		# Só conta como "pulo em cima" se o contato veio de cima do inimigo
		# (normal apontando para cima), não de um encontrão pela lateral.
		if corpo and corpo.is_in_group("inimigo") and colisao.get_normal().y < -0.5:
			if corpo.has_method("recebe_dano"):
				corpo.recebe_dano(DANO_PULO)
				# Pequeno quique pra cima, pra não ficar "grudado" em pé em
				# cima do inimigo — fica mais parecido com o pulo do Mario.
				velocity.y = JUMP_VELOCITY * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill"):
		arremessar()


func arremessar() -> void:
	if cena_lapis == null:
		return

	var agora := Time.get_ticks_msec() / 1000.0
	if agora - ultimo_arremesso_tempo < COOLDOWN_ARREMESSO:
		return
	ultimo_arremesso_tempo = agora

	var lapis = cena_lapis.instantiate()
	get_tree().current_scene.add_child(lapis)

	if Input.is_action_pressed("cima"):
		# Arremesso vertical: toca a animação de braço erguido e o lápis sai
		# da posição da mão nessa pose, não do centro genérico do corpo.
		_sprite.flip_h = direcao_olhando < 0.0
		_tocar_animacao_acao("arremesso_vertical")
		lapis.global_position = _sprite.global_position + Vector2(
			offset_mao_vertical.x * direcao_olhando, offset_mao_vertical.y
		)

		# Sobe reto pra cima com velocidade própria e, depois de um tempo,
		# a gravidade vence e ele cai de volta.
		lapis.direcao = 0.0
		lapis.usar_gravidade = true
		lapis.velocidade_y = -velocidade_lancamento_vertical
		lapis.rotation = -PI / 2.0
	else:
		# Sai do centro do corpo do jogador (centro do sprite), não da origem
		# do CharacterBody2D, que fica deslocada acima/à esquerda do corpo.
		lapis.global_position = _sprite.global_position + Vector2(direcao_olhando * 15.0, 0.0)
		lapis.direcao = direcao_olhando

		# Se o jogador estiver no ar, o lápis segue uma trajetória de
		# lançamento horizontal (velocidade horizontal constante + gravidade
		# puxando para baixo). No chão, o lápis segue em linha reta.
		if not is_on_floor():
			lapis.usar_gravidade = true


func receber_dano(dano: int) -> void:
	# Enquanto estiver invencível, ignora novos hits — evita levar vários
	# danos seguidos só por ficar encostado no inimigo.
	if invencivel:
		return

	vida = max(vida - dano, 0)
	print("Vida do jogador: ", vida)

	if has_node("BarraVida"):
		$BarraVida.definir_vida(vida, VIDA_MAXIMA)

	if vida <= 0:
		print("Jogador morreu")
		queue_free()
		return

	_ativar_invencibilidade()


func _ativar_invencibilidade() -> void:
	invencivel = true

	# Desliga de verdade a colisão do jogador com inimigos durante esse
	# tempo: zera a própria camada (ninguém o detecta) e tira dos inimigos
	# da sua máscara (ele não empurra/é empurrado por eles). O chão continua
	# na máscara, então ele não cai por baixo do mundo.
	collision_layer = 0
	collision_mask = _mascara_colisao_original & ~CAMADA_INIMIGOS

	var tween := create_tween()
	tween.set_loops(int(DURACAO_INVENCIVEL / 0.16))
	tween.tween_property(self, "modulate:a", 0.25, 0.08)
	tween.tween_property(self, "modulate:a", 1.0, 0.08)

	await get_tree().create_timer(DURACAO_INVENCIVEL).timeout
	invencivel = false
	collision_layer = _camada_colisao_original
	collision_mask = _mascara_colisao_original
	modulate.a = 1.0
