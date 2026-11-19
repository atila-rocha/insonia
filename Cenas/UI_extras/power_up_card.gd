class_name PowerUpCard
extends Button

# Avisos (signals) que a carta envia para a cena de seleção
signal escolhido(dados: PowerUpData)
signal mouse_sobre(dados: PowerUpData)
signal mouse_saiu

const COR_TEXTO_NORMAL := Color("8B8FA0")
const COR_TEXTO_SELECIONADO := Color("2A1D10")

var dados: PowerUpData
var _mouse_em_cima := false
var _tween: Tween

@onready var icone: TextureRect = %Icone
@onready var nome: Label = %Nome


func _ready() -> void:
	# Faz todos os nós filhos "ignorarem" o mouse.
	# Sem isso, o clique cairia em um filho e o botão não reagiria.
	$MarginContainer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for filho in find_children("*", "Control", true, false):
		filho.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# O ponto central da carta é onde ela "cresce" (escala).
	resized.connect(_atualizar_pivo)
	_atualizar_pivo()

	mouse_entered.connect(_ao_mouse_entrar)
	mouse_exited.connect(_ao_mouse_sair)
	button_down.connect(_ao_apertar)
	button_up.connect(_ao_soltar)
	toggled.connect(_ao_alternar)

	nome.add_theme_color_override("font_color", COR_TEXTO_NORMAL)


# Chamada pela cena de seleção para preencher a carta
func configurar(novos_dados: PowerUpData) -> void:
	dados = novos_dados
	icone.texture = dados.icone
	nome.text = dados.nome


# Chamada depois que o jogador confirma
func travar(escolhida: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	_mouse_em_cima = false
	if escolhida:
		_animar(1.1)
	else:
		_animar(0.9)
		var t := create_tween()
		t.tween_property(self, "modulate:a", 0.3, 0.2)


func _atualizar_pivo() -> void:
	pivot_offset = size / 2.0


# Tamanho que a carta deve ter agora, conforme o estado
func _escala_alvo() -> float:
	if button_pressed:
		return 1.1
	if _mouse_em_cima:
		return 1.06
	return 1.0


func _animar(escala: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * escala, 0.1)


func _ao_mouse_entrar() -> void:
	_mouse_em_cima = true
	_animar(_escala_alvo())
	mouse_sobre.emit(dados)


func _ao_mouse_sair() -> void:
	_mouse_em_cima = false
	_animar(_escala_alvo())
	mouse_saiu.emit()


func _ao_apertar() -> void:
	_animar(0.94) # encolhe um pouco enquanto o botão está apertado


func _ao_soltar() -> void:
	_animar(_escala_alvo())


func _ao_alternar(ligado: bool) -> void:
	var cor := COR_TEXTO_SELECIONADO if ligado else COR_TEXTO_NORMAL
	nome.add_theme_color_override("font_color", cor)
	if ligado:
		_pop.call_deferred() # espera o fim do clique para não conflitar
		escolhido.emit(dados)
	else:
		_animar(_escala_alvo())


# Animação de "estouro" ao selecionar: cresce além do tamanho e volta
func _pop() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * 1.25, 0.08)
	_tween.tween_property(self, "scale", Vector2.ONE * 1.1, 0.12)
