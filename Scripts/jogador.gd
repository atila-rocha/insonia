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

# ---------------- Sanidade (GDD, tabela "Barra de Sanidade") ----------------
# A "vida" do jogador é a barra de sanidade. Valores por segundo, a balancear.
const DECAIMENTO_PASSIVO = 0.2      # passivo: quase imperceptível
const DECAIMENTO_PERSEGUIDO = 2.0   # sendo perseguido: decai rapidamente
const RECUPERACAO_SAFE_ZONE = 6.0   # sentado no banco: recupera continuamente
const DANO_QUEDA = 10               # caiu num buraco: volta ao último chão

# ---------------- Power-ups ----------------
const MULTIPLICADOR_SPRINT = 1.6
const DURACAO_SPRINT = 2.0
const COOLDOWN_SPRINT = 3.0
const BONUS_RAIO_LANTERNA = 60.0

@export var cena_lapis: PackedScene = preload("res://Cenas/Habilidades/lapis.tscn")
@export var velocidade_lancamento_vertical: float = 650.0
@export var cena_comida: PackedScene = preload("res://Cenas/Objetos/comida.tscn")
## Se o jogador cair abaixo desta altura (buraco/água), volta ao último chão.
## A cena da fase ajusta esse valor.
@export var limite_queda_y: float = 100000.0

var vida: int = VIDA_MAXIMA
var direcao_olhando: float = 1.0
var ultimo_arremesso_tempo: float = -COOLDOWN_ARREMESSO
var invencivel: bool = false
var _camada_colisao_original: int
var _mascara_colisao_original: int

## Lido pelos perseguidores: true quando o Leo está sentado num banco.
var na_safe_zone: bool = false
var sentado: bool = false
var desmaiado: bool = false

var _sanidade_acumulada: float = 0.0
var _interativos: Array[Node] = []
var _ultima_posicao_segura: Vector2
var _pulo_extra_disponivel: bool = false
var _sprint_restante: float = DURACAO_SPRINT
var _sprint_cooldown: float = 0.0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _holofote: Node = get_node_or_null("Holofote")
@onready var _camera: Camera2D = get_node_or_null("Camera2D")


func _ready() -> void:
	add_to_group("jogador")
	_camada_colisao_original = collision_layer
	_mascara_colisao_original = collision_mask
	_ultima_posicao_segura = global_position

	if has_node("BarraVida"):
		$BarraVida.definir_vida_maxima(VIDA_MAXIMA)

	if _holofote and EstadoJogo.tem_power_up(&"light"):
		_holofote.raio += BONUS_RAIO_LANTERNA

	_avisar_sanidade.call_deferred()
	get_tree().call_group.call_deferred("hud", "atualizar_comidas", EstadoJogo.comidas)


func _physics_process(delta: float) -> void:
	if desmaiado:
		return

	_atualizar_sanidade(delta)

	# Guarda se já estava caindo antes deste frame, para saber depois do
	# move_and_slide() se o que aconteceu foi um "pulo em cima" do inimigo.
	var estava_caindo := velocity.y > 0.0

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if sentado:
		_processar_sentado()
		move_and_slide()
		_tocar_animacao("idle")
		return

	# Handle jump.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
		elif _pulo_extra_disponivel:
			# Power-up "Pulo duplo": um segundo pulo no ar.
			_pulo_extra_disponivel = false
			velocity.y = JUMP_VELOCITY * 0.9

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("left", "right")
	var velocidade := SPEED * _fator_sprint(delta, direction != 0.0)
	if direction:
		velocity.x = direction * velocidade
		direcao_olhando = sign(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if is_on_floor():
		_ultima_posicao_segura = global_position
		_pulo_extra_disponivel = EstadoJogo.tem_power_up(&"double")

	# Pulo em cima (ou pousar/ficar em cima) de um inimigo.
	if estava_caindo or is_on_floor():
		_verificar_pulo_em_inimigo()

	_verificar_queda()
	_atualizar_animacao()


func _atualizar_animacao() -> void:
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
	if desmaiado:
		return
	if event.is_action_pressed("skill") and not sentado:
		arremessar()
	elif event.is_action_pressed("interagir"):
		_interagir()
	elif event.is_action_pressed("soltar_comida"):
		soltar_comida()


func arremessar() -> void:
	if cena_lapis == null:
		return

	var agora := Time.get_ticks_msec() / 1000.0
	if agora - ultimo_arremesso_tempo < COOLDOWN_ARREMESSO:
		return
	ultimo_arremesso_tempo = agora

	var lapis = cena_lapis.instantiate()
	get_tree().current_scene.add_child(lapis)
	# Sai do centro do corpo do jogador (centro do sprite).
	lapis.global_position = _sprite.global_position + Vector2(direcao_olhando * 15.0, 0.0)

	if Input.is_action_pressed("cima"):
		# Arremesso vertical: sobe reto pra cima com velocidade própria e,
		# depois de um tempo, a gravidade vence e ele cai de volta.
		lapis.direcao = 0.0
		lapis.usar_gravidade = true
		lapis.velocidade_y = -velocidade_lancamento_vertical
		lapis.rotation = -PI / 2.0
	else:
		lapis.direcao = direcao_olhando

		# Se o jogador estiver no ar, o lápis segue uma trajetória de
		# lançamento horizontal (velocidade horizontal constante + gravidade
		# puxando para baixo). No chão, o lápis segue em linha reta.
		if not is_on_floor():
			lapis.usar_gravidade = true


func receber_dano(dano: int) -> void:
	# Enquanto estiver invencível, ignora novos hits — evita levar vários
	# danos seguidos só por ficar encostado no inimigo.
	if invencivel or desmaiado:
		return

	_alterar_vida(-dano)
	print("Vida do jogador: ", vida)

	if has_node("BarraVida"):
		$BarraVida.definir_vida(vida, VIDA_MAXIMA)

	if vida <= 0:
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


# ======================= Sanidade =======================

## Função de decaimento linear (GDD): sanidade -= taxa * delta.
## Como "vida" é inteiro, os pedacinhos de cada frame são somados em
## _sanidade_acumulada e só viram ponto inteiro quando passam de 1.
func _atualizar_sanidade(delta: float) -> void:
	var taxa := -DECAIMENTO_PASSIVO
	if na_safe_zone:
		taxa = RECUPERACAO_SAFE_ZONE
	elif _esta_sendo_perseguido():
		taxa = -DECAIMENTO_PERSEGUIDO

	_sanidade_acumulada += taxa * delta
	if absf(_sanidade_acumulada) >= 1.0:
		var pontos := int(_sanidade_acumulada)
		_sanidade_acumulada -= pontos
		_alterar_vida(pontos)


func _esta_sendo_perseguido() -> bool:
	for p in get_tree().get_nodes_in_group("perseguidor"):
		if p.has_method("esta_perseguindo") and p.esta_perseguindo():
			return true
	return false


func _alterar_vida(quantidade: int) -> void:
	if desmaiado:
		return
	vida = clampi(vida + quantidade, 0, VIDA_MAXIMA)
	_avisar_sanidade()
	if vida <= 0:
		_desmaiar()


func _avisar_sanidade() -> void:
	if _holofote and _holofote.has_method("atualizar_sanidade"):
		_holofote.atualizar_sanidade(vida, VIDA_MAXIMA)
	get_tree().call_group("hud", "atualizar_sanidade", vida, VIDA_MAXIMA)


## Sanidade chegou a 0%: desmaio emocional (Game Over). Volta ao início da
## fase mantendo o que foi salvo (comidas e power-ups em EstadoJogo).
func _desmaiar() -> void:
	desmaiado = true
	sentado = false
	na_safe_zone = false
	velocity = Vector2.ZERO
	print("Jogador morreu")
	get_tree().call_group("hud", "mostrar_desmaio")

	await get_tree().create_timer(3.0).timeout
	var arquivo := get_tree().current_scene.scene_file_path
	if arquivo == EstadoJogo.CENA_FASE_1 or arquivo == EstadoJogo.CENA_BATALHA_1:
		get_tree().change_scene_to_file(EstadoJogo.cena_fase_atual)
	else:
		get_tree().reload_current_scene()


func _verificar_queda() -> void:
	if global_position.y < limite_queda_y:
		return
	global_position = _ultima_posicao_segura
	velocity = Vector2.ZERO
	if _camera:
		_camera.reset_smoothing()
	receber_dano(DANO_QUEDA)


# ======================= Safe zone (banco) =======================

func sentar() -> void:
	if not is_on_floor():
		return
	sentado = true
	na_safe_zone = true
	velocity.x = 0.0
	_atualizar_dica()


func levantar() -> void:
	sentado = false
	na_safe_zone = false
	_atualizar_dica()


func _processar_sentado() -> void:
	velocity.x = 0.0
	# Andar ou pular faz o Leo levantar do banco.
	if Input.get_axis("left", "right") != 0.0 or Input.is_action_just_pressed("jump"):
		levantar()


# ======================= Interação (tecla E) =======================

## Bancos, baús e portas se registram aqui quando o Leo chega perto.
func adicionar_interativo(objeto: Node) -> void:
	if not objeto in _interativos:
		_interativos.append(objeto)
	_atualizar_dica()


func remover_interativo(objeto: Node) -> void:
	_interativos.erase(objeto)
	_atualizar_dica()


func _interagir() -> void:
	if sentado:
		levantar()
		return
	var alvo = _interativo_atual()
	if alvo:
		alvo.interagir(self)
		_atualizar_dica()


func _interativo_atual() -> Node:
	for objeto in _interativos:
		if is_instance_valid(objeto) and objeto.has_method("interagir"):
			return objeto
	return null


func _atualizar_dica() -> void:
	var texto := ""
	if sentado:
		texto = "[E] Levantar"
	else:
		var alvo = _interativo_atual()
		if alvo and alvo.has_method("texto_dica"):
			texto = alvo.texto_dica()
	get_tree().call_group("hud", "mostrar_dica", texto)


# ======================= Comida (tecla F) =======================

## Solta uma comida no chão. Os perseguidores próximos param para comer.
func soltar_comida() -> void:
	if EstadoJogo.comidas <= 0 or cena_comida == null or sentado:
		return
	EstadoJogo.comidas -= 1
	var comida = cena_comida.instantiate()
	get_tree().current_scene.add_child(comida)
	comida.global_position = global_position
	get_tree().call_group("hud", "atualizar_comidas", EstadoJogo.comidas)


func ganhar_comida(quantidade: int = 1) -> void:
	EstadoJogo.comidas += quantidade
	get_tree().call_group("hud", "atualizar_comidas", EstadoJogo.comidas)


# ======================= Sprint (power-up) =======================

func _fator_sprint(delta: float, andando: bool) -> float:
	if not EstadoJogo.tem_power_up(&"sprint"):
		return 1.0
	if _sprint_cooldown > 0.0:
		_sprint_cooldown -= delta
		if _sprint_cooldown <= 0.0:
			_sprint_restante = DURACAO_SPRINT
		return 1.0
	if andando and Input.is_action_pressed("run"):
		_sprint_restante -= delta
		if _sprint_restante <= 0.0:
			_sprint_cooldown = COOLDOWN_SPRINT
		return MULTIPLICADOR_SPRINT
	return 1.0
