extends Control

# Barra de vida estilo "boss": fundo escuro, preenchimento vermelho
# segmentado e um texto "atual/total" no centro. Quando a vida muda,
# a barra anima suavemente até o novo valor (efeito de "cair").

signal vida_zerada

@export var vida_maxima: int = 100
@export var num_segmentos: int = 8
@export var duracao_animacao: float = 0.4

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

@onready var _label: Label = $LabelValores


func _ready() -> void:
	vida_atual = vida_maxima
	vida_exibida = float(vida_maxima)

	_caixa_fundo.bg_color = cor_fundo
	_caixa_fundo.border_color = cor_borda
	_caixa_fundo.set_border_width_all(3)

	_caixa_vida.bg_color = cor_vida

	_atualizar_raios()
	_atualizar_label()


func definir_vida_maxima(valor: int) -> void:
	vida_maxima = max(valor, 1)
	visible = true
	modulate.a = 1.0
	definir_vida(vida_maxima, vida_maxima)


func definir_vida(atual: int, maxima: int) -> void:
	vida_maxima = max(maxima, 1)
	vida_atual = clamp(atual, 0, vida_maxima)

	_animar_para(vida_atual)
	_atualizar_label()

	if vida_atual <= 0:
		vida_zerada.emit()
		_esconder_com_fade()


func _esconder_com_fade() -> void:
	var tween_fade := create_tween()
	tween_fade.tween_property(self, "modulate:a", 0.0, 0.6)
	tween_fade.tween_callback(func() -> void: visible = false)


func receber_dano(dano: int) -> void:
	definir_vida(vida_atual - dano, vida_maxima)


func curar(quantidade: int) -> void:
	definir_vida(vida_atual + quantidade, vida_maxima)


func _animar_para(valor: int) -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "vida_exibida", float(valor), duracao_animacao)


func _atualizar_label() -> void:
	_label.text = "%d/%d" % [vida_atual, vida_maxima]


func _atualizar_raios() -> void:
	var raio := int(size.y * 0.5)
	_caixa_fundo.set_corner_radius_all(raio)
	_caixa_vida.set_corner_radius_all(max(raio - 4, 0))


func _draw() -> void:
	_atualizar_raios()
	draw_style_box(_caixa_fundo, Rect2(Vector2.ZERO, size))

	var margem := 5.0
	var area := Rect2(Vector2(margem, margem), size - Vector2(margem, margem) * 2.0)
	var proporcao: float = clamp(vida_exibida / float(vida_maxima), 0.0, 1.0)
	var largura := area.size.x * proporcao

	if largura > 1.0:
		draw_style_box(_caixa_vida, Rect2(area.position, Vector2(largura, area.size.y)))

	if num_segmentos > 1:
		var largura_segmento := area.size.x / float(num_segmentos)
		for i in range(1, num_segmentos):
			var x := area.position.x + largura_segmento * i
			draw_line(Vector2(x, area.position.y), Vector2(x, area.position.y + area.size.y), cor_fundo, 2.0)
