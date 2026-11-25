extends Control

# Barra de vida reutilizável. Por padrão funciona acima de inimigos, mas a
# HUD pode mantê-la na tela alterando `esconder_apos_inatividade`.

@export var vida_maxima: int = 10
@export var tempo_visivel: float = 1.5
@export var duracao_animacao: float = 0.25
@export var esconder_apos_inatividade: bool = true
@export var mostrar_valores: bool = false
## Ativa o acabamento angular azul/laranja usado pela HUD de sanidade.
## Desligado por padrão para não alterar as barras flutuantes dos inimigos.
@export var estilo_hud: bool = false

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
@onready var _label_valores: Label = get_node_or_null("LabelValores")


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
	_atualizar_label()

	visible = not esconder_apos_inatividade


func definir_vida_maxima(valor: int) -> void:
	vida_maxima = max(valor, 1)
	vida_atual = vida_maxima
	vida_exibida = float(vida_maxima)
	_atualizar_label()


func definir_vida(atual: int, maxima: int) -> void:
	vida_maxima = max(maxima, 1)
	vida_atual = clamp(atual, 0, vida_maxima)

	visible = true
	modulate.a = 1.0
	_animar_para(vida_atual)
	_atualizar_label()
	if esconder_apos_inatividade:
		_timer_esconder.start(tempo_visivel)


func receber_dano(dano: int) -> void:
	definir_vida(vida_atual - dano, vida_maxima)


func _on_timer_esconder_timeout() -> void:
	if esconder_apos_inatividade:
		visible = false


func _atualizar_label() -> void:
	if _label_valores:
		_label_valores.visible = mostrar_valores
		_label_valores.text = "%d / %d" % [vida_atual, vida_maxima]


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
	if estilo_hud:
		_desenhar_estilo_hud()
		return

	_atualizar_raios()
	draw_style_box(_caixa_fundo, Rect2(Vector2.ZERO, size))

	var margem := 3.0
	var area := Rect2(Vector2(margem, margem), size - Vector2(margem, margem) * 2.0)
	var proporcao: float = clamp(vida_exibida / float(vida_maxima), 0.0, 1.0)
	var largura := area.size.x * proporcao

	if largura > 1.0:
		draw_style_box(_caixa_vida, Rect2(area.position, Vector2(largura, area.size.y)))


func _desenhar_estilo_hud() -> void:
	# Moldura angular, sem cantos arredondados, para manter a leitura de pixel art
	# mesmo em resoluções maiores.
	var rect_externo := Rect2(Vector2.ZERO, size)
	var cor_sombra := Color("070a13")
	var cor_moldura := Color("31496e")
	var cor_interior := Color("0a1426")

	draw_colored_polygon(_poligono_cortado(rect_externo, 7.0), cor_sombra)
	draw_colored_polygon(_poligono_cortado(Rect2(Vector2(2, 2), size - Vector2(4, 4)), 5.0), cor_moldura)
	draw_colored_polygon(_poligono_cortado(Rect2(Vector2(5, 5), size - Vector2(10, 10)), 3.0), cor_interior)

	var area := Rect2(Vector2(9, 9), size - Vector2(18, 18))
	var proporcao: float = clamp(vida_exibida / float(vida_maxima), 0.0, 1.0)
	var largura := int(floor(area.size.x * proporcao))

	if largura <= 0:
		return

	# Gradiente quente para frio como no storyboard: laranja, dourado e azul.
	for x in range(largura):
		var denominador: float = maxf(float(largura - 1), 1.0)
		var t: float = float(x) / denominador
		draw_rect(Rect2(area.position + Vector2(x, 0), Vector2(1, area.size.y)), _cor_sanidade(t))

	# Brilho discreto no topo para separar o preenchimento da moldura escura.
	draw_line(area.position + Vector2(0, 1), area.position + Vector2(largura - 1, 1), Color(1.0, 0.86, 0.65, 0.38), 1.0)


func _poligono_cortado(rect: Rect2, corte: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(corte, 0),
		rect.position + Vector2(rect.size.x - corte, 0),
		rect.position + Vector2(rect.size.x, corte),
		rect.position + Vector2(rect.size.x, rect.size.y - corte),
		rect.position + Vector2(rect.size.x - corte, rect.size.y),
		rect.position + Vector2(corte, rect.size.y),
		rect.position + Vector2(0, rect.size.y - corte),
		rect.position + Vector2(0, corte),
	])


func _cor_sanidade(t: float) -> Color:
	if t < 0.48:
		return Color("ef7543").lerp(Color("ffc76e"), t / 0.48)
	return Color("ffc76e").lerp(Color("3197d2"), (t - 0.48) / 0.52)
