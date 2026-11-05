extends Control

# Barra de vida para inimigos comuns: fica em cima da cabeça do inimigo
# (é filha dele, então se move junto) e some sozinha um tempo depois do
# último dano recebido.

@export var vida_maxima: int = 10
@export var tempo_visivel: float = 1.5
@export var duracao_animacao: float = 0.25

@export var cor_fundo: Color = Color(0.07, 0.05, 0.06)
@export var cor_borda: Color = Color(0.6, 0.58, 0.55)
@export var cor_vida: Color = Color(0.74, 0.08, 0.1)

var vida_atual: int

var vida_exibida: float:
	set(valor):
		vida_exibida = valor
		queue_redraw()

var _tween: Tween
var _caixa_fundo := StyleBoxFlat.new()
var _caixa_vida := StyleBoxFlat.new()

@onready var _timer_esconder: Timer = $TimerEsconder


func _ready() -> void:
	vida_atual = vida_maxima
	vida_exibida = float(vida_maxima)

	_caixa_fundo.bg_color = cor_fundo
	_caixa_fundo.border_color = cor_borda
	_caixa_fundo.set_border_width_all(2)
	_caixa_vida.bg_color = cor_vida

	_atualizar_raios()
	_timer_esconder.one_shot = true
	_timer_esconder.timeout.connect(_on_timer_esconder_timeout)

	visible = false  # só aparece quando o inimigo toma o primeiro dano


func definir_vida_maxima(valor: int) -> void:
	vida_maxima = max(valor, 1)
	vida_atual = vida_maxima
	vida_exibida = float(vida_maxima)


func definir_vida(atual: int, maxima: int) -> void:
	vida_maxima = max(maxima, 1)
	vida_atual = clamp(atual, 0, vida_maxima)

	visible = true
	modulate.a = 1.0
	_animar_para(vida_atual)
	_timer_esconder.start(tempo_visivel)


func receber_dano(dano: int) -> void:
	definir_vida(vida_atual - dano, vida_maxima)


func _on_timer_esconder_timeout() -> void:
	visible = false


func _animar_para(valor: int) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "vida_exibida", float(valor), duracao_animacao)


func _atualizar_raios() -> void:
	var raio := int(size.y * 0.5)
	_caixa_fundo.set_corner_radius_all(raio)
	_caixa_vida.set_corner_radius_all(max(raio - 3, 0))


func _draw() -> void:
	_atualizar_raios()
	draw_style_box(_caixa_fundo, Rect2(Vector2.ZERO, size))

	var margem := 3.0
	var area := Rect2(Vector2(margem, margem), size - Vector2(margem, margem) * 2.0)
	var proporcao: float = clamp(vida_exibida / float(vida_maxima), 0.0, 1.0)
	var largura := area.size.x * proporcao

	if largura > 1.0:
		draw_style_box(_caixa_vida, Rect2(area.position, Vector2(largura, area.size.y)))
