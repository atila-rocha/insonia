extends AnimatableBody2D

signal vida_alterada(atual: int, maxima: int)

enum Estado { VOANDO, PREPARANDO, MERGULHANDO, PAIRANDO, SUBINDO }

@export var vida_maxima: int = 190

@export var velocidade_patrulha: float = 120.0
@export var velocidade_mergulho: float = 420.0
@export var velocidade_subida: float = 260.0

## Quanto tempo o pombo fica "travado no ar" avisando o ataque antes de
## realmente mergulhar — a janela que o jogador tem pra perceber e fugir.
@export var duracao_preparacao: float = 0.5

## Quanto tempo (em segundos) à frente o pombo "antecipa" o movimento do
## jogador ao mirar o mergulho — sem isso ele sempre mira exatamente onde
## o jogador estava, ficando sempre um passo atrás de quem está em movimento.
## Baixo de propósito: o jogador ainda consegue escapar se sair do lugar.
@export var antecipacao_mira: float = 0.15

## Limites de patrulha em coordenadas globais. Se ficarem em (0, 0)
## o boss usa automaticamente as bordas da tela.
@export var limite_esquerdo: float = 0.0
@export var limite_direito: float = 0.0

@export var dano_mergulho: int = 20

## Altura (em pixels, acima do centro do jogador) em que o pombo para ao
## mergulhar. Pequena de propósito — o pombo tem que realmente alcançar o
## jogador lá embaixo, não só chegar perto.
@export var altura_acima_do_jogador: float = 10.0

## Quanto tempo o pombo fica parado lá embaixo antes de subir de novo —
## é a janela que o jogador tem pra revidar com pulo ou lápis.
@export var duracao_pairar_embaixo: float = 0.6

@export var tempo_minimo_para_mergulhar: float = 4.0
@export var tempo_maximo_para_mergulhar: float = 8.0

## Tempo máximo perseguindo o jogador durante o mergulho antes de desistir
## e subir de volta, caso ele consiga fugir o tempo todo.
@export var duracao_maxima_mergulho: float = 2.5

# Tempo pequeno de "imunidade" logo depois de levar um dano.
const DURACAO_INVENCIVEL_DANO = 0.25
const DISTANCIA_MINIMA_ALVO = 12.0

var vida: int
var direcao: float = 1.0
var estado: Estado = Estado.VOANDO
var invencivel_a_dano: bool = false

var _altura_cruzeiro: float
var _alvo_mergulho: Vector2
var _jogador_alvo = null
var _tempo_mergulho: float = 0.0

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

	_altura_cruzeiro = global_position.y
	_sprite.play("voando")
	_agendar_proximo_mergulho()


func _physics_process(delta: float) -> void:
	match estado:
		Estado.VOANDO:
			_patrulhar(delta)
		Estado.PREPARANDO:
			pass  # trava no lugar avisando o ataque, só esperando o timer
		Estado.MERGULHANDO:
			_tempo_mergulho += delta

			# O alvo foi travado quando o mergulho começou (fim do aviso) e
			# NÃO é mais atualizado aqui — o pombo voa em linha reta até esse
			# ponto fixo. Se o jogador sair do lugar durante o mergulho, o
			# ataque erra de verdade, em vez de curvar atrás dele.
			_mover_em_direcao(_alvo_mergulho, velocidade_mergulho, delta)

			if global_position.distance_to(_alvo_mergulho) <= DISTANCIA_MINIMA_ALVO or _tempo_mergulho >= duracao_maxima_mergulho:
				_pairar_embaixo()
		Estado.PAIRANDO:
			pass  # fica parado, só esperando o timer do _pairar_embaixo()
		Estado.SUBINDO:
			var alvo := Vector2(global_position.x, _altura_cruzeiro)
			_mover_em_direcao(alvo, velocidade_subida, delta)
			if absf(global_position.y - _altura_cruzeiro) <= DISTANCIA_MINIMA_ALVO:
				_terminar_mergulho()


func _patrulhar(delta: float) -> void:
	position.x += velocidade_patrulha * direcao * delta

	if direcao > 0.0 and global_position.x >= limite_direito:
		direcao = -1.0
		_atualizar_flip()
	elif direcao < 0.0 and global_position.x <= limite_esquerdo:
		direcao = 1.0
		_atualizar_flip()


func _mover_em_direcao(alvo: Vector2, velocidade: float, delta: float) -> void:
	var diferenca := alvo - global_position
	var distancia := diferenca.length()

	if distancia <= 0.0:
		return

	var passo := minf(velocidade * delta, distancia)
	global_position += diferenca.normalized() * passo

	if diferenca.x != 0.0:
		direcao = signf(diferenca.x)
		_atualizar_flip()


func _atualizar_flip() -> void:
	_sprite.flip_h = direcao < 0.0


# Sorteia quanto tempo falta até o próximo mergulho. Um intervalo de 4 a 8
# segundos dá tempo do jogador respirar entre um ataque e outro, sem deixar
# o pombo parado voando em círculos por tempo demais.
func _agendar_proximo_mergulho() -> void:
	var espera := randf_range(tempo_minimo_para_mergulhar, tempo_maximo_para_mergulhar)
	get_tree().create_timer(espera).timeout.connect(_iniciar_mergulho)


func _iniciar_mergulho() -> void:
	if estado != Estado.VOANDO:
		return

	_jogador_alvo = get_tree().get_first_node_in_group("jogador")
	if _jogador_alvo == null:
		_agendar_proximo_mergulho()
		return

	# Aviso antes do mergulho: trava no ar, já com a animação de ataque,
	# mas ainda sem se mover — dá tempo do jogador perceber e sair do lugar
	# antes do bote de verdade começar.
	estado = Estado.PREPARANDO
	_sprite.play("mergulho")
	get_tree().create_timer(duracao_preparacao).timeout.connect(_comecar_mergulho_de_verdade)


func _comecar_mergulho_de_verdade() -> void:
	if estado != Estado.PREPARANDO:
		return  # o boss pode ter morrido ou sido interrompido nesse meio tempo

	estado = Estado.MERGULHANDO
	_tempo_mergulho = 0.0
	_alvo_mergulho = _calcular_alvo_mergulho()

	# Desliga o corpo sólido durante a descida — senão ele esbarra no
	# jogador no meio do caminho (vira uma "parede") e nunca chega no alvo.
	# O dano continua valendo, porque a AreaDano é um nó separado.
	_colisao_solida.disabled = true


func _calcular_alvo_mergulho() -> Vector2:
	# IMPORTANTE: não usar _jogador_alvo.global_position direto — a origem
	# do CharacterBody2D do jogador fica bem deslocada do corpo visível dele
	# (o sprite/colisão têm um offset local grande). Mirar na origem fazia
	# o pombo convergir pra um ponto vazio, bem longe do jogador de verdade.
	var posicao_real_jogador: Vector2 = _jogador_alvo.global_position
	if _jogador_alvo.has_node("AnimatedSprite2D"):
		posicao_real_jogador = _jogador_alvo.get_node("AnimatedSprite2D").global_position

	# Mira na posição do jogador MAIS um pedaço do caminho que a velocidade
	# atual dele percorreria em "antecipacao_mira" segundos — assim o pombo
	# mira um pouco à frente de para onde o jogador está indo, em vez de
	# mirar sempre exatamente onde ele estava no instante da leitura.
	var previsao: Vector2 = posicao_real_jogador
	if "velocity" in _jogador_alvo:
		previsao += _jogador_alvo.velocity * antecipacao_mira

	return previsao - Vector2(0, altura_acima_do_jogador)


func _pairar_embaixo() -> void:
	estado = Estado.PAIRANDO
	# Volta a ser sólido parado lá embaixo, pra dar pra pular em cima dele.
	_colisao_solida.disabled = false
	get_tree().create_timer(duracao_pairar_embaixo).timeout.connect(_comecar_subida)


func _comecar_subida() -> void:
	estado = Estado.SUBINDO
	_sprite.play("voando")
	_colisao_solida.disabled = true


func _terminar_mergulho() -> void:
	estado = Estado.VOANDO
	_colisao_solida.disabled = false
	_agendar_proximo_mergulho()


func recebe_dano(dano: int) -> void:
	if invencivel_a_dano:
		return

	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)
	print("Vida do boss (pombo): ", vida)

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
		body.receber_dano(dano_mergulho)
