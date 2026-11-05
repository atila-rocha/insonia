class_name Holofote
extends PointLight2D
## Holofote circular ao redor do jogador (GDD: "Visão limitada a um holofote").
## - Luz uniforme do centro até a borda, cor #FFC27A, sem sombras.
## - Escurece o mapa com um CanvasModulate (#1E2230).
## - Filtro cinza: com sanidade baixa, a luz vai para #BDBDBD e o ambiente para #2A2A2A (lerp, sem shader).
## - Detecção: esta_iluminado() compara a distância ao raio (distance_to).
## - Power-up: aumentar_raio().

@export_group("Holofote")
## Raio da luz em pixels.
@export var raio: float = 160.0:
	set(valor):
		raio = maxf(valor, 1.0)
		_aplicar_raio()
@export var cor_normal: Color = Color("#FFC27A")
@export var cor_sanidade_baixa: Color = Color("#BDBDBD")

@export_group("Ambiente")
@export var ambiente_normal: Color = Color("#3C4466")
@export var ambiente_sanidade_baixa: Color = Color("#2A2A2A")
## Fração da sanidade em que o filtro cinza começa (0.5 = começa em 50%).
@export_range(0.0, 1.0) var inicio_filtro_cinza: float = 0.5
## Velocidade da transição de cor (maior = mais rápido).
@export var velocidade_transicao: float = 2.0

const TAMANHO_TEXTURA := 256

var _ambiente: CanvasModulate
var _sanidade_alvo := 1.0
var _sanidade_atual := 1.0


func _ready() -> void:
	add_to_group("holofote")
	shadow_enabled = false
	energy = 1.0
	color = cor_normal
	_criar_textura()
	_aplicar_raio()
	_configurar_ambiente()


func _process(delta: float) -> void:
	_sanidade_atual = lerpf(_sanidade_atual, _sanidade_alvo, minf(velocidade_transicao * delta, 1.0))
	var peso := _peso_cinza(_sanidade_atual)
	color = cor_normal.lerp(cor_sanidade_baixa, peso)
	if _ambiente:
		_ambiente.color = ambiente_normal.lerp(ambiente_sanidade_baixa, peso)


# ---------------- Funções públicas (para o resto do grupo usar) ----------------

## Chamar sempre que a sanidade mudar. Ex.: holofote.atualizar_sanidade(sanidade, sanidade_max)
func atualizar_sanidade(atual: float, maxima: float) -> void:
	_sanidade_alvo = clampf(atual / maxima, 0.0, 1.0) if maxima > 0.0 else 0.0


## true se a posição (global) estiver dentro da luz. Usado pelos perseguidores
## para trocar "olhos brilhantes" pelo sprite do animal.
func esta_iluminado(posicao_global: Vector2) -> bool:
	return global_position.distance_to(posicao_global) <= raio


## Power-up "Aumento do raio de visão".
func aumentar_raio(quantidade: float, duracao: float = 0.5) -> void:
	var tween := create_tween()
	tween.tween_property(self, "raio", raio + quantidade, duracao)


# ---------------- Interno ----------------

func _criar_textura() -> void:
	# Círculo branco uniforme com borda quase dura (só 2% de suavização).
	var gradiente := Gradient.new()
	gradiente.offsets = PackedFloat32Array([0.0, 0.98, 1.0])
	gradiente.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(0, 0, 0, 0)])

	var textura := GradientTexture2D.new()
	textura.gradient = gradiente
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = TAMANHO_TEXTURA
	textura.height = TAMANHO_TEXTURA
	texture = textura


func _aplicar_raio() -> void:
	if texture:
		texture_scale = raio * 2.0 / TAMANHO_TEXTURA


func _configurar_ambiente() -> void:
	# Usa o CanvasModulate da fase se ele estiver no grupo "ambiente_escuro";
	# se não existir, cria um automaticamente.
	_ambiente = get_tree().get_first_node_in_group("ambiente_escuro") as CanvasModulate
	if _ambiente == null:
		_ambiente = CanvasModulate.new()
		_ambiente.name = "AmbienteEscuro"
		_ambiente.add_to_group("ambiente_escuro")
		get_tree().current_scene.add_child.call_deferred(_ambiente)
	_ambiente.color = ambiente_normal


func _peso_cinza(sanidade: float) -> float:
	if inicio_filtro_cinza <= 0.0:
		return 0.0
	return clampf(1.0 - sanidade / inicio_filtro_cinza, 0.0, 1.0)
