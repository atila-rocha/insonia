extends CanvasLayer
## HUD minimalista (GDD, seção 6): barra de sanidade, comidas coletadas,
## dica de interação, mensagens rápidas e a tela de desmaio.
## O jogador conversa com o HUD pelo grupo "hud" (call_group), então o HUD
## pode ficar em qualquer cena sem precisar de caminho fixo.

const FONTE := preload("res://Assets/Fonts/Pixelify_Sans/static/PixelifySans-Bold.ttf")
const ICONE_COMIDA := preload("res://Assets/icons/pet-bowl.png")

## Cores da barra: quente com sanidade alta, cinza com sanidade baixa
## (as mesmas do holofote, para o filtro cinza "conversar" com a barra).
@export var cor_sanidade_alta: Color = Color("FFC27A")
@export var cor_sanidade_baixa: Color = Color("BDBDBD")
@export var largura_barra: float = 220.0

var _barra: ProgressBar
var _estilo_preenchimento: StyleBoxFlat
var _rotulo_valor: Label
var _rotulo_comida: Label
var _dica: Label
var _mensagem: Label
var _cortina: ColorRect
var _texto_desmaio: Label
var _tween_barra: Tween
var _tween_mensagem: Tween


func _ready() -> void:
	add_to_group("hud")
	layer = 5
	_montar_painel_sanidade()
	_montar_textos()
	_montar_cortina()


# ---------------- Funções chamadas pelo jogo ----------------

func atualizar_sanidade(atual: float, maxima: float) -> void:
	var fracao := clampf(atual / maxima, 0.0, 1.0) if maxima > 0.0 else 0.0
	_barra.max_value = maxima
	if _tween_barra:
		_tween_barra.kill()
	_tween_barra = create_tween()
	_tween_barra.tween_property(_barra, "value", atual, 0.25)
	_rotulo_valor.text = "%d%%" % roundi(fracao * 100.0)
	# Abaixo de 50% a barra vai ficando cinza, junto com o filtro do holofote.
	var peso := clampf(1.0 - fracao / 0.5, 0.0, 1.0)
	_estilo_preenchimento.bg_color = cor_sanidade_alta.lerp(cor_sanidade_baixa, peso)


func atualizar_comidas(quantidade: int) -> void:
	_rotulo_comida.text = "x %d" % quantidade


func mostrar_dica(texto: String) -> void:
	_dica.text = texto
	_dica.visible = not texto.is_empty()


func mostrar_mensagem(texto: String, duracao: float = 2.5) -> void:
	_mensagem.text = texto
	_mensagem.modulate.a = 1.0
	if _tween_mensagem:
		_tween_mensagem.kill()
	_tween_mensagem = create_tween()
	_tween_mensagem.tween_interval(duracao)
	_tween_mensagem.tween_property(_mensagem, "modulate:a", 0.0, 0.6)


func mostrar_desmaio() -> void:
	_texto_desmaio.text = "Leo desmaiou de exaustão...\n\nTudo bem falhar e descansar.\nVamos tentar de novo."
	_cortina.visible = true
	var tween := create_tween()
	tween.tween_property(_cortina, "color:a", 0.9, 1.2)
	tween.parallel().tween_property(_texto_desmaio, "modulate:a", 1.0, 1.2)


func escurecer_tela(duracao: float = 0.6) -> void:
	_texto_desmaio.text = ""
	_cortina.visible = true
	create_tween().tween_property(_cortina, "color:a", 1.0, duracao)


func clarear_tela(duracao: float = 0.6) -> void:
	_cortina.visible = true
	_cortina.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_cortina, "color:a", 0.0, duracao)
	tween.tween_callback(func() -> void: _cortina.visible = false)


# ---------------- Montagem da interface ----------------

func _rotulo(tamanho: int, cor: Color = Color("e8e2d6")) -> Label:
	var rotulo := Label.new()
	rotulo.add_theme_font_override("font", FONTE)
	rotulo.add_theme_font_size_override("font_size", tamanho)
	rotulo.add_theme_color_override("font_color", cor)
	rotulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	rotulo.add_theme_constant_override("outline_size", 4)
	return rotulo


func _montar_painel_sanidade() -> void:
	var painel := PanelContainer.new()
	painel.position = Vector2(16, 14)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.06, 0.07, 0.1, 0.72)
	fundo.border_color = Color(0.6, 0.58, 0.55, 0.8)
	fundo.set_border_width_all(2)
	fundo.set_corner_radius_all(6)
	fundo.set_content_margin_all(10)
	painel.add_theme_stylebox_override("panel", fundo)
	add_child(painel)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 6)
	painel.add_child(coluna)

	var linha_titulo := HBoxContainer.new()
	coluna.add_child(linha_titulo)
	var titulo := _rotulo(14, Color("a8b8c8"))
	titulo.text = "SANIDADE"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha_titulo.add_child(titulo)
	_rotulo_valor = _rotulo(14)
	_rotulo_valor.text = "100%"
	linha_titulo.add_child(_rotulo_valor)

	_barra = ProgressBar.new()
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(largura_barra, 14)
	_barra.max_value = 100
	_barra.value = 100
	var fundo_barra := StyleBoxFlat.new()
	fundo_barra.bg_color = Color(0.12, 0.1, 0.11)
	fundo_barra.set_corner_radius_all(4)
	_estilo_preenchimento = StyleBoxFlat.new()
	_estilo_preenchimento.bg_color = cor_sanidade_alta
	_estilo_preenchimento.set_corner_radius_all(4)
	_barra.add_theme_stylebox_override("background", fundo_barra)
	_barra.add_theme_stylebox_override("fill", _estilo_preenchimento)
	coluna.add_child(_barra)

	var linha_comida := HBoxContainer.new()
	linha_comida.add_theme_constant_override("separation", 6)
	coluna.add_child(linha_comida)
	var icone := TextureRect.new()
	icone.texture = ICONE_COMIDA
	icone.custom_minimum_size = Vector2(22, 22)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	linha_comida.add_child(icone)
	_rotulo_comida = _rotulo(14)
	_rotulo_comida.text = "x 0"
	linha_comida.add_child(_rotulo_comida)
	var ajuda := _rotulo(13, Color("8b8fa0"))
	ajuda.text = "   [F] soltar comida"
	linha_comida.add_child(ajuda)


func _montar_textos() -> void:
	_dica = _rotulo(18)
	_dica.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dica.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dica.offset_top = -60
	_dica.offset_bottom = -30
	_dica.offset_left = -300
	_dica.offset_right = 300
	_dica.visible = false
	add_child(_dica)

	_mensagem = _rotulo(24, Color("FFC27A"))
	_mensagem.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensagem.offset_top = 110
	_mensagem.offset_bottom = 150
	_mensagem.offset_left = -400
	_mensagem.offset_right = 400
	_mensagem.modulate.a = 0.0
	add_child(_mensagem)


func _montar_cortina() -> void:
	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.visible = false
	add_child(_cortina)

	_texto_desmaio = _rotulo(26)
	_texto_desmaio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_texto_desmaio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_desmaio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_desmaio.modulate.a = 0.0
	_cortina.add_child(_texto_desmaio)
