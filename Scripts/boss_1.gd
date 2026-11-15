extends StaticBody2D

signal vida_alterada(atual: int, maxima: int)

enum Estado { PATRULHANDO, COMECANDO_A_ROLAR, ROLANDO, DESENROLANDO }

@export var vida_maxima: int = 480

## Limites de patrulha em coordenadas globais. Se ficarem em (0, 0)
## o boss usa automaticamente as bordas da tela.
@export var velocidade: float = 100.0
@export var limite_esquerdo: float = 0.0
@export var limite_direito: float = 0.0

@export var dano_contato: int = 20
@export var dano_rolamento: int = 35

@export var velocidade_rolamento: float = 320.0
@export var tempo_minimo_para_rolar: float = 4.0
@export var tempo_maximo_para_rolar: float = 7.0
@export var duracao_comecando_a_rolar: float = 0.8
@export var duracao_rolando: float = 1.5
@export var duracao_desenrolando: float = 0.6

# Tempo pequeno de "imunidade" logo depois de levar um dano, pra um pulo em
# cima ou dois lápis quase juntos não contarem como dois hits separados.
const DURACAO_INVENCIVEL_DANO = 0.25

var vida: int
var direcao: float = 1.0
var estado: Estado = Estado.PATRULHANDO
var invencivel_a_dano: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


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

	_sprite.play("correndo")
	_agendar_proximo_rolamento()


func _physics_process(delta: float) -> void:
	if estado == Estado.PATRULHANDO or estado == Estado.ROLANDO:
		var vel := velocidade_rolamento if estado == Estado.ROLANDO else velocidade
		position.x += vel * direcao * delta

		if direcao > 0.0 and global_position.x >= limite_direito:
			direcao = -1.0
			_atualizar_flip()
		elif direcao < 0.0 and global_position.x <= limite_esquerdo:
			direcao = 1.0
			_atualizar_flip()


func _atualizar_flip() -> void:
	_sprite.flip_h = direcao < 0.0


# Sorteia quanto tempo falta até o próximo ataque de rolamento. Um intervalo
# de 4 a 7 segundos dá tempo do jogador atacar/se posicionar entre um
# rolamento e outro, sem deixar o boss muito previsível nem muito parado.
func _agendar_proximo_rolamento() -> void:
	var espera := randf_range(tempo_minimo_para_rolar, tempo_maximo_para_rolar)
	get_tree().create_timer(espera).timeout.connect(_iniciar_rolamento)


func _iniciar_rolamento() -> void:
	if estado != Estado.PATRULHANDO:
		return

	estado = Estado.COMECANDO_A_ROLAR
	_sprite.play("comecando_a_rolar")
	get_tree().create_timer(duracao_comecando_a_rolar).timeout.connect(_entrar_em_rolamento)


func _entrar_em_rolamento() -> void:
	estado = Estado.ROLANDO
	_sprite.play("rolando")
	get_tree().create_timer(duracao_rolando).timeout.connect(_comecar_a_desenrolar)


func _comecar_a_desenrolar() -> void:
	estado = Estado.DESENROLANDO
	_sprite.play("desenrolando")
	get_tree().create_timer(duracao_desenrolando).timeout.connect(_terminar_rolamento)


func _terminar_rolamento() -> void:
	estado = Estado.PATRULHANDO
	_sprite.play("correndo")
	_agendar_proximo_rolamento()


func recebe_dano(dano: int) -> void:
	if invencivel_a_dano:
		return

	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)
	print("Vida do boss: ", vida)

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
		var dano := dano_rolamento if estado == Estado.ROLANDO else dano_contato
		body.receber_dano(dano)
