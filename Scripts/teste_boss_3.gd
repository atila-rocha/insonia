extends Node2D

@onready var boss = $Boss3
@onready var barra_vida_boss = $HUD/BarraVidaBoss
@onready var camera_arena = $CameraArena


func _ready() -> void:
	# Em cena de boss, a câmera fica fixa mostrando a arena inteira — não
	# segue o jogador (que tem sua própria câmera, usada nas outras cenas).
	camera_arena.make_current()

	barra_vida_boss.definir_vida_maxima(boss.vida_maxima)
	boss.vida_alterada.connect(_on_boss_vida_alterada)


func _on_boss_vida_alterada(atual: int, maxima: int) -> void:
	barra_vida_boss.definir_vida(atual, maxima)
