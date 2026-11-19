class_name EstadoJogo
extends RefCounted
## Guarda o que precisa sobreviver à troca de cena (fase -> batalha -> fase).
## Usa variáveis "static": existem uma vez só para o jogo inteiro, sem
## precisar de Autoload. Ex.: EstadoJogo.comidas += 1

const CENA_MENU := "res://Cenas/UI_extras/main_menu.tscn"
const CENA_FASE_1 := "res://Cenas/Fase_1/fase_1_jogo.tscn"
const CENA_BATALHA_1 := "res://Cenas/Fase_1/batalha_pombo.tscn"

## Quantidade de comida carregada (a quantidade passa de uma fase para outra).
static var comidas: int = 0
## Ids dos power-ups escolhidos ("double", "sprint", "light", "food").
static var power_ups: Array[StringName] = []
## Ids das entradas do Codex já desbloqueadas ("pombo", "formiga"...).
static var codex_desbloqueado: Array[StringName] = []
## Fase em que o jogador está (para onde volta ao desmaiar).
static var cena_fase_atual: String = CENA_FASE_1
## Fragmentos da liberdade coletados (um por batalha vencida).
static var fragmentos: int = 0


static func novo_jogo() -> void:
	comidas = 0
	power_ups.clear()
	codex_desbloqueado.clear()
	cena_fase_atual = CENA_FASE_1
	fragmentos = 0


static func tem_power_up(id: StringName) -> bool:
	return id in power_ups


static func desbloquear_codex(id: StringName) -> void:
	if not id in codex_desbloqueado:
		codex_desbloqueado.append(id)
