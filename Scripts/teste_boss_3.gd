extends Node2D

@onready var boss = $Boss3
@onready var barra_vida_boss = $HUD/BarraVidaBoss


func _ready() -> void:
	barra_vida_boss.definir_vida_maxima(boss.vida_maxima)
	boss.vida_alterada.connect(_on_boss_vida_alterada)


func _on_boss_vida_alterada(atual: int, maxima: int) -> void:
	barra_vida_boss.definir_vida(atual, maxima)
