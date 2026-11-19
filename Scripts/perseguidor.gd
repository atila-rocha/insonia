class_name Perseguidor
extends CharacterBody2D
## Perseguidor da Fase 1: revoada de pombos (GDD, seção 2).
##
## Máquina de estados finita (FSM) com enum + match:
##   PATRULHA    -> voa de um lado para o outro até ver o Leo
##   PERSEGUICAO -> persegue com ATRASO: vai até onde o Leo estava ~1 s antes (fila de posições)
##   AGRESSIVO   -> igual à perseguição, porém mais rápido (sanidade baixa)
##   IGNORANDO   -> o Leo está sentado numa safe zone
##   COMENDO     -> distraído com comida
##
## Ao alcançar o Leo, tira 20% da barra (chama receber_dano no jogador).

enum Estado { PATRULHA, PERSEGUICAO, AGRESSIVO, IGNORANDO, COMENDO }

@export_group("Movimento")
@export var velocidade: float = 110.0
@export var velocidade_agressiva: float = 170.0
## Distância que ele anda para cada lado durante a patrulha.
@export var distancia_patrulha: float = 150.0
## Marque se o sprite original olha para a direita.
@export var sprite_olha_para_direita: bool = false

@export_group("Perseguição")
## A esta distância (ou menos) ele começa a perseguir.
@export var raio_deteccao: float = 350.0
## Se o Leo ficar mais longe que isso, ele desiste e volta a patrulhar.
@export var raio_perda: float = 550.0
## Atraso da revoada em segundos (GDD: cerca de 1 segundo).
@export var atraso: float = 1.0

@export_group("Dano")
## 20% de uma barra de 100.
@export var dano: int = 20
## Distância entre os centros para contar como "alcançou".
@export var raio_contato: float = 40.0
## Tempo mínimo entre um dano e outro.
@export var tempo_entre_danos: float = 1.5

@export_group("Sanidade baixa")
@export var sanidade_maxima: float = 100.0
## Abaixo desta fração da sanidade ele fica agressivo (0.3 = 30%).
@export_range(0.0, 1.0) var limiar_agressivo: float = 0.3

@export_group("Visual")
## Pombos voam por cima de tudo: sem colisão com paredes nem com o jogador.
## Desmarque para perseguidores que andam pelo chão (gato, gambá...).
@export var atravessa_paredes: bool = true
## Cria os "olhos brilhantes" automaticamente se a cena não tiver o nó Olhos.
@export var criar_olhos: bool = true
## Posição dos olhos em relação ao centro do perseguidor.
@export var posicao_olhos: Vector2 = Vector2(10, -10)

@export_group("Depuração")
## Mostra no painel Saída cada troca de estado.
@export var mostrar_estado: bool = true

var estado: Estado = Estado.PATRULHA:
	set(novo):
		if novo != estado and mostrar_estado:
			print(name, " -> ", Estado.keys()[novo])
		estado = novo

var _alvo: Node2D
var _holofote: Node
var _fila: Array = []  # fila de [tempo, posição] do Leo
var _tempo := 0.0
var _ultimo_dano := -999.0
var _origem: Vector2
var _direcao_patrulha := 1.0
var _comida_pos: Vector2
var _tempo_comendo := 0.0

@onready var _sprite: CanvasItem = get_node_or_null("AnimatedSprite2D")
@onready var _olhos: CanvasItem = get_node_or_null("Olhos")


func _ready() -> void:
	add_to_group("perseguidor")
	# Pombos voam: sem gravidade, movimento livre em X e Y.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if atravessa_paredes:
		collision_layer = 0
		collision_mask = 0
	_origem = global_position
	if _olhos == null and criar_olhos:
		_olhos = _criar_olhos()


func _physics_process(delta: float) -> void:
	_tempo += delta
	_procurar_referencias()

	if _alvo:
		_gravar_posicao_do_leo()
		_atualizar_estado()

	match estado:
		Estado.PATRULHA, Estado.IGNORANDO:
			_patrulhar()
		Estado.PERSEGUICAO:
			_perseguir(velocidade)
		Estado.AGRESSIVO:
			_perseguir(velocidade_agressiva)
		Estado.COMENDO:
			_comer(delta)

	move_and_slide()
	_verificar_contato()
	_atualizar_visual()


# ---------------- Funções públicas ----------------

## true enquanto estiver perseguindo o Leo (usado pela barra de sanidade).
func esta_perseguindo() -> bool:
	return estado == Estado.PERSEGUICAO or estado == Estado.AGRESSIVO


## Chamar quando o Leo soltar comida (tecla F). O perseguidor vai até ela e para para comer.
func distrair(posicao_comida: Vector2, duracao: float = 4.0) -> void:
	# Para um pouco acima da comida, para o corpo não ficar "dentro" do chão.
	_comida_pos = posicao_comida + Vector2(0, -16)
	_tempo_comendo = duracao
	estado = Estado.COMENDO


# ---------------- Estados ----------------

func _atualizar_estado() -> void:
	if estado == Estado.COMENDO:
		return

	# Safe zone: o jogador precisa ter a variável na_safe_zone = true quando sentado no banco.
	if _alvo.get("na_safe_zone") == true:
		estado = Estado.IGNORANDO
		_fila.clear()
		return

	var distancia := global_position.distance_to(_posicao_do_leo())
	var perseguindo := estado == Estado.PERSEGUICAO or estado == Estado.AGRESSIVO

	if not perseguindo and distancia <= raio_deteccao:
		perseguindo = true
	elif perseguindo and distancia > raio_perda:
		perseguindo = false
		_origem = global_position  # passa a patrulhar onde perdeu o Leo

	if perseguindo:
		estado = Estado.AGRESSIVO if _sanidade_baixa() else Estado.PERSEGUICAO
	else:
		estado = Estado.PATRULHA


func _patrulhar() -> void:
	if global_position.x > _origem.x + distancia_patrulha:
		_direcao_patrulha = -1.0
	elif global_position.x < _origem.x - distancia_patrulha:
		_direcao_patrulha = 1.0
	velocity = Vector2(_direcao_patrulha * velocidade * 0.5, 0.0)


func _perseguir(vel: float) -> void:
	if _fila.is_empty():
		velocity = Vector2.ZERO
		return
	# O início da fila é onde o Leo estava há "atraso" segundos.
	var destino: Vector2 = _fila[0][1]
	if global_position.distance_to(destino) < 4.0:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(destino) * vel


func _comer(delta: float) -> void:
	if global_position.distance_to(_comida_pos) > 8.0:
		velocity = global_position.direction_to(_comida_pos) * velocidade
		return
	velocity = Vector2.ZERO
	_tempo_comendo -= delta
	if _tempo_comendo <= 0.0:
		_origem = global_position
		estado = Estado.PATRULHA


# ---------------- Auxiliares ----------------

## Fila (push_back / pop_front): guarda as últimas posições do Leo
## e descarta as que já passaram do atraso.
func _gravar_posicao_do_leo() -> void:
	_fila.push_back([_tempo, _posicao_do_leo()])
	while _fila.size() > 1 and _tempo - _fila[1][0] >= atraso:
		_fila.pop_front()


func _verificar_contato() -> void:
	if _alvo == null or estado == Estado.IGNORANDO or estado == Estado.COMENDO:
		return
	if global_position.distance_to(_posicao_do_leo()) > raio_contato:
		return
	if _tempo - _ultimo_dano < tempo_entre_danos:
		return
	_ultimo_dano = _tempo
	if _alvo.has_method("receber_dano"):
		_alvo.receber_dano(dano)


## Fora da luz: só os olhos. Dentro da luz: sprite do animal (usa o holofote).
func _atualizar_visual() -> void:
	if _sprite is AnimatedSprite2D:
		var anim := "comer" if estado == Estado.COMENDO else "voar"
		if _sprite.animation != anim and _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim):
			_sprite.play(anim)

	if _sprite is AnimatedSprite2D and absf(velocity.x) > 1.0:
		var indo_para_esquerda := velocity.x < 0.0
		_sprite.flip_h = indo_para_esquerda if sprite_olha_para_direita else not indo_para_esquerda

	if _holofote == null or not _holofote.has_method("esta_iluminado"):
		return
	var iluminado: bool = _holofote.esta_iluminado(global_position)
	if _sprite:
		_sprite.visible = iluminado
	if _olhos:
		_olhos.visible = not iluminado
		if _sprite is AnimatedSprite2D:
			# Os olhos acompanham o lado para onde o perseguidor olha.
			var olhando_direita: bool = _sprite.flip_h != sprite_olha_para_direita
			_olhos.position.x = absf(posicao_olhos.x) * (1.0 if olhando_direita else -1.0)


## Olhos brilhantes no escuro (GDD): um ponto laranja que ignora a escuridão
## (Light Mode = Unshaded), visível só fora do holofote.
func _criar_olhos() -> Node2D:
	var imagem := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for x in 5:
		for y in 5:
			var d := absi(x - 2) + absi(y - 2)
			if d == 0:
				imagem.set_pixel(x, y, Color("fff4be"))
			elif d == 1:
				imagem.set_pixel(x, y, Color(1.0, 0.6, 0.25, 0.9))
			elif d == 2:
				imagem.set_pixel(x, y, Color(1.0, 0.35, 0.15, 0.35))
	var olhos := Sprite2D.new()
	olhos.name = "Olhos"
	olhos.texture = ImageTexture.create_from_image(imagem)
	olhos.scale = Vector2(2, 2)
	olhos.position = posicao_olhos
	var material_olhos := CanvasItemMaterial.new()
	material_olhos.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	olhos.material = material_olhos
	olhos.z_index = 5
	add_child(olhos)
	return olhos


func _sanidade_baixa() -> bool:
	var sanidade = _alvo.get("vida")
	if sanidade == null:
		return false
	return float(sanidade) / sanidade_maxima <= limiar_agressivo


## Posição real do Leo na tela. Usa a colisão dele, porque o corpo do
## jogador pode estar deslocado do sprite dentro de jogador.tscn.
func _posicao_do_leo() -> Vector2:
	var colisao := _alvo.get_node_or_null("CollisionShape2D") as Node2D
	return colisao.global_position if colisao else _alvo.global_position


func _procurar_referencias() -> void:
	if _alvo != null and not is_instance_valid(_alvo):
		_alvo = null
	if _alvo == null:
		_alvo = get_tree().get_first_node_in_group("jogador") as Node2D
		if _alvo is PhysicsBody2D:
			add_collision_exception_with(_alvo)  # não empurra o Leo, só causa dano
	if _holofote == null:
		_holofote = get_tree().get_first_node_in_group("holofote")
