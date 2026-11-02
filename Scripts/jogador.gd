extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const VIDA_MAXIMA = 100
const COOLDOWN_ARREMESSO = 1.5

@export var cena_lapis: PackedScene = preload("res://Cenas/lapis.tscn")

var vida: int = VIDA_MAXIMA
var direcao_olhando: float = 1.0
var ultimo_arremesso_tempo: float = -COOLDOWN_ARREMESSO


func _ready() -> void:
	add_to_group("jogador")


func _physics_process(delta: float) -> void:
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
	# Sai do centro do corpo do jogador (centro do sprite), não da origem
	# do CharacterBody2D, que fica deslocada acima/à esquerda do corpo.
	lapis.global_position = $AnimatedSprite2D.global_position + Vector2(direcao_olhando * 15.0, 0.0)
	lapis.direcao = direcao_olhando

	# Se o jogador estiver no ar, o lápis segue uma trajetória de
	# lançamento horizontal (velocidade horizontal constante + gravidade
	# puxando para baixo). No chão, o lápis segue em linha reta.
	if not is_on_floor():
		lapis.usar_gravidade = true


func receber_dano(dano: int) -> void:
	vida -= dano
	print("Vida do jogador: ", vida)

	if vida <= 0:
		print("Jogador morreu")
		queue_free()
