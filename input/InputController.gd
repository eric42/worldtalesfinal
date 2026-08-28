extends Node2D
class_name InputController


# =========================================================
# REFERENCES
# =========================================================

@export var battle_map_path: NodePath
@export var unit_manager_path: NodePath
@export var turn_manager_path: NodePath
@export var game_state_path: NodePath
@export var preview_ui_path: NodePath
@export var action_menu_path: NodePath


@onready var map: BattleMap = get_node(battle_map_path)
@onready var unit_manager: UnitManager = get_node(unit_manager_path)
@onready var turn_manager: TurnManager = get_node(turn_manager_path)
@onready var game_state: GameStateManager = get_node(game_state_path)
@onready var preview_ui: CombatPreviewUI = get_node(preview_ui_path)
@onready var action_menu: ActionMenuUI = get_node(action_menu_path)


# =========================================================
# SELECTION
# =========================================================

var selected_unit: HeroUnit = null
var pending_action_unit: HeroUnit = null

var original_position: Vector2i = Vector2i(-1, -1)


# =========================================================
# ATTACK MODE
# =========================================================

var attack_mode: bool = false

# Cópia dos tiles válidos no momento em que Attack
# é selecionado.
var cached_attack_tiles: Array[Vector2i] = []


# =========================================================
# INIT
# =========================================================

func _ready() -> void:

	assert(map)
	assert(unit_manager)
	assert(turn_manager)
	assert(game_state)
	assert(action_menu)

	# Evita conexão duplicada caso este método seja chamado
	# novamente durante testes/reload.
	if not action_menu.attack_selected.is_connected(_on_attack_selected):
		action_menu.attack_selected.connect(_on_attack_selected)

	if not action_menu.wait_selected.is_connected(_on_wait_selected):
		action_menu.wait_selected.connect(_on_wait_selected)

	if not action_menu.cancel_selected.is_connected(_on_cancel_selected):
		action_menu.cancel_selected.connect(_on_cancel_selected)

	print("InputController pronto")


# =========================================================
# INPUT
# =========================================================

func _input(event: InputEvent) -> void:

	# =====================================================
	# FILTRA MOUSE
	# =====================================================

	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not event.pressed:
		return


	# =====================================================
	# MODO ATAQUE
	#
	# IMPORTANTE:
	# ataque é processado ANTES de verificar
	# is_player_input_allowed().
	# =====================================================

	if attack_mode:

		var mouse_pos: Vector2 = map.get_local_mouse_position()
		var grid: Vector2i = map.world_to_grid(mouse_pos)

		print("================================")
		print("INPUT RECEBIDO EM ATTACK MODE")
		print("Mouse local:", mouse_pos)
		print("Grid:", grid)
		print("Attack mode:", attack_mode)
		print("Cached tiles:", cached_attack_tiles)
		print("GameState:", game_state.current_state)
		print("================================")

		_handle_attack_click(grid)

		get_viewport().set_input_as_handled()

		return


	# =====================================================
	# INPUT NORMAL
	# =====================================================

	if not game_state.is_player_input_allowed():
		return


	var mouse_pos: Vector2 = map.get_local_mouse_position()
	var grid: Vector2i = map.world_to_grid(mouse_pos)

	map.set_hovered_tile(grid)


	# =====================================================
	# FORA DO MAPA
	# =====================================================

	if not map.is_inside_map(grid):

		_reset_selection()

		return


	# =====================================================
	# PROCURA UNIDADE
	# =====================================================

	var unit: HeroUnit = unit_manager.get_unit_at(grid)


	# =====================================================
	# SELEÇÃO
	# =====================================================

	if (
		is_instance_valid(unit)
		and unit.faction == Faction.Type.ALLY
		and not unit.has_acted
	):

		_select_unit(unit)

		return


	# =====================================================
	# MOVIMENTO
	# =====================================================

	if (
		is_instance_valid(selected_unit)
		and map.is_tile_reachable(grid)
	):

		await _move_selected_unit(grid)

		return


	# =====================================================
	# RESET
	# =====================================================

	_reset_selection()

func _select_unit(unit: HeroUnit) -> void:

	# Se já estamos com outra unidade selecionada,
	# limpa a seleção anterior.
	if selected_unit != unit:

		attack_mode = false
		cached_attack_tiles.clear()

		map.clear_hover_preview()


	selected_unit = unit

	print("")
	print("=== SELECIONOU ===")
	print("Unit:", unit)
	print("Pos:", unit.grid_pos)


	original_position = unit.grid_pos


	# =====================================================
	# CALCULA MOVIMENTO
	# =====================================================

	var blocked: Array[Vector2i] = (
		unit_manager.get_occupied_tiles()
	)

	var reachable: Array[Vector2i] = (
		map.compute_reachable_tiles(
			unit,
			blocked
		)
	)

	map.show_reachable_tiles(reachable)


	# =====================================================
	# CALCULA ATAQUES POSSÍVEIS
	# =====================================================

	var attack_tiles: Array[Vector2i] = (
		map.compute_attack_tiles_from_movement(
			unit,
			reachable
		)
	)

	map.show_attack_tiles(attack_tiles)


	var targets: Array[HeroUnit] = (
		map.get_attackable_units(
			unit,
			attack_tiles
		)
	)

	print("Tiles de ataque enviados:", attack_tiles)
	print("Alvos possíveis:", targets)


# =========================================================
# MOVIMENTO
# =========================================================

func _move_selected_unit(grid: Vector2i) -> void:

	if not is_instance_valid(selected_unit):
		return


	# =====================================================
	# ENTRA EM ANIMAÇÃO
	# =====================================================

	game_state.set_state(
		GameStateManager.State.PLAYER_ANIMATING
	)


	var blocked: Array[Vector2i] = (
		unit_manager.get_occupied_tiles()
	)


	var path: Array[Vector2i] = (
		map.get_grid_path(
			selected_unit.grid_pos,
			grid,
			selected_unit,
			blocked
		)
	)


	if path.is_empty():

		game_state.set_state(
			GameStateManager.State.PLAYER_ACTION
		)

		return


	# =====================================================
	# MOVE
	# =====================================================

	var tween: Tween = (
		map.move_unit_along_path(
			selected_unit,
			path
		)
	)


	if tween != null:
		await tween.finished


	map.clear_hover_preview()


	# =====================================================
	# UNIDADE AGORA ESTÁ NA NOVA POSIÇÃO
	# =====================================================

	pending_action_unit = selected_unit


	# =====================================================
	# RECALCULA ATAQUES APÓS O MOVIMENTO
	#
	# Isso é importante porque o ataque depende da posição
	# atual da unidade.
	# =====================================================

	var new_reachable: Array[Vector2i] = (
		map.compute_reachable_tiles(
			pending_action_unit,
			unit_manager.get_occupied_tiles()
		)
	)


	var new_attack_tiles: Array[Vector2i] = (
		map.compute_attack_tiles_from_movement(
			pending_action_unit,
			new_reachable
		)
	)


	map.show_attack_tiles(new_attack_tiles)


	print("Tiles de ataque apos mover:", new_attack_tiles)


	# =====================================================
	# PLAYER ACTION
	# =====================================================

	game_state.set_state(
		GameStateManager.State.PLAYER_ACTION
	)


	# =====================================================
	# MOSTRA MENU
	# =====================================================

	action_menu.show_menu(
		pending_action_unit.global_position
	)


# =========================================================
# ATTACK BUTTON
# =========================================================

func _on_attack_selected() -> void:

	print("================================")
	print(">>> _on_attack_selected() CHAMADO")
	print("pending:", pending_action_unit)
	print("selected:", selected_unit)
	print("attack_mode ANTES:", attack_mode)
	print("attack_tiles:", map.attack_tiles)
	print("================================")


	# =====================================================
	# SEGURANÇA
	# =====================================================

	if not is_instance_valid(pending_action_unit):

		print("ERRO: nenhuma unidade pendente")

		return


	if attack_mode:

		print("Já está no modo ataque")

		return


	# =====================================================
	# GARANTE QUE A UNIDADE ATIVA É A PENDENTE
	# =====================================================

	selected_unit = pending_action_unit


	# =====================================================
	# COPIA OS TILES DE ATAQUE
	#
	# Não dependemos de um array que possa ser alterado
	# enquanto o modo ataque estiver ativo.
	# =====================================================

	cached_attack_tiles = map.attack_tiles.duplicate()


	print("Tiles válidos para ataque:", cached_attack_tiles)


	# =====================================================
	# NÃO HÁ ALVOS
	# =====================================================

	if cached_attack_tiles.is_empty():

		print("Nenhum alvo disponível")

		attack_mode = false

		return

	# =====================================================
	# ATIVA MODO ATAQUE
	# =====================================================

	attack_mode = true

	print("Modo ataque ativado")
	print("Tiles validos:", cached_attack_tiles)

	# Mantém os tiles vermelhos.
	map.show_attack_tiles(cached_attack_tiles)

	# Remove previews anteriores.
	map.clear_hover_preview()
	map.show_hover_attack_tiles([])

	# O menu não deve continuar sobre o campo de batalha.
	action_menu.hide()
	
func _handle_attack_click(tile: Vector2i) -> void:

	print("================================")
	print(">>> CLIQUE EM MODO ATAQUE")
	print("Tile:", tile)
	print("Attack mode:", attack_mode)
	print("Tiles válidos:", cached_attack_tiles)
	print("================================")


	# =====================================================
	# GARANTE QUE AINDA EXISTE UM ATACANTE
	# =====================================================

	if not is_instance_valid(pending_action_unit):

		print("Nenhuma unidade atacante")

		_exit_attack_mode()

		return


	# =====================================================
	# VERIFICA TILE
	#
	# Usa cached_attack_tiles, não recalcula nada.
	# =====================================================

	if tile not in cached_attack_tiles:

		print("Tile NÃO é atacável:", tile)

		return


	# =====================================================
	# PROCURA UNIDADE NO TILE
	# =====================================================

	var target: HeroUnit = unit_manager.get_unit_at(tile)


	if not is_instance_valid(target):

		print("Nenhuma unidade neste tile:", tile)

		return


	# =====================================================
	# VERIFICA FACÇÃO
	# =====================================================

	if target.faction == pending_action_unit.faction:

		print("Não pode atacar aliado")

		return


	# =====================================================
	# VERIFICAÇÃO FINAL DE ATAQUE
	# =====================================================

	if not can_attack(
		pending_action_unit,
		target
	):

		print("Alvo fora do alcance real")

		return


	print("================================")
	print(">>> ALVO SELECIONADO")
	print("Atacante:", pending_action_unit)
	print("Alvo:", target)
	print("================================")


	# =====================================================
	# SAI DO MODO ATAQUE ANTES DE EXECUTAR
	# =====================================================

	attack_mode = false
	cached_attack_tiles.clear()


	# =====================================================
	# ENTRA EM ANIMAÇÃO
	# =====================================================

	game_state.set_state(
		GameStateManager.State.PLAYER_ANIMATING
	)


	map.clear_hover_preview()


	# =====================================================
	# EXECUTA ATAQUE
	# =====================================================

	if is_instance_valid(pending_action_unit):

		map.execute_attack(
			pending_action_unit,
			target
		)


	# =====================================================
	# MARCA AÇÃO
	# =====================================================

	if is_instance_valid(pending_action_unit):

		pending_action_unit.has_acted = true


	# =====================================================
	# LIMPA UI
	# =====================================================

	action_menu.hide()

	preview_ui.hide_preview()

	map.clear_selection()


	# =====================================================
	# LIMPA REFERÊNCIAS
	# =====================================================

	selected_unit = null
	pending_action_unit = null


	# =====================================================
	# FINALIZA AÇÃO
	# =====================================================

	game_state.set_state(
		GameStateManager.State.IDLE
	)


	# =====================================================
	# VERIFICA FIM DO TURNO
	# =====================================================

	if unit_manager.all_player_units_acted():

		turn_manager.end_current_turn()


# =========================================================
# WAIT
# =========================================================

func _on_wait_selected() -> void:

	print("WAIT selecionado")


	if not is_instance_valid(pending_action_unit):

		return


	pending_action_unit.has_acted = true


	# =====================================================
	# SAI DO MODO ATAQUE
	# =====================================================

	attack_mode = false
	cached_attack_tiles.clear()


	# =====================================================
	# LIMPA SELEÇÃO
	# =====================================================

	selected_unit = null
	pending_action_unit = null


	map.clear_selection()
	map.clear_hover_preview()


	preview_ui.hide_preview()


	action_menu.hide()


	# =====================================================
	# VOLTA PARA IDLE
	# =====================================================

	game_state.set_state(
		GameStateManager.State.IDLE
	)


	print(
		"Estado atual:",
		game_state.current_state
	)


	# =====================================================
	# VERIFICA FIM DO TURNO
	# =====================================================

	if unit_manager.all_player_units_acted():

		turn_manager.end_current_turn()


# =========================================================
# CANCEL
# =========================================================

func _on_cancel_selected() -> void:

	if not is_instance_valid(pending_action_unit):

		return


	# =====================================================
	# RESTAURA POSIÇÃO ORIGINAL
	# =====================================================

	pending_action_unit.set_grid_pos(
		original_position
	)

	pending_action_unit.position = (
		map.grid_to_world(
			original_position
		)
	)


	# =====================================================
	# CANCELA ATAQUE
	# =====================================================

	attack_mode = false
	cached_attack_tiles.clear()


	selected_unit = pending_action_unit
	pending_action_unit = null


	# =====================================================
	# LIMPA PREVIEWS
	# =====================================================

	map.clear_hover_preview()

	preview_ui.hide_preview()


	# =====================================================
	# VOLTA PARA IDLE
	# =====================================================

	game_state.set_state(
		GameStateManager.State.IDLE
	)


	# =====================================================
	# RECALCULA MOVIMENTO
	# =====================================================

	var blocked: Array[Vector2i] = (
		unit_manager.get_occupied_tiles()
	)


	var reachable: Array[Vector2i] = (
		map.compute_reachable_tiles(
			selected_unit,
			blocked
		)
	)


	map.show_reachable_tiles(
		reachable
	)


	# =====================================================
	# RECALCULA ATAQUE
	# =====================================================

	var attack_tiles: Array[Vector2i] = (
		map.compute_attack_tiles_from_movement(
			selected_unit,
			reachable
		)
	)


	map.show_attack_tiles(
		attack_tiles
	)


# =========================================================
# RESET SELECTION
# =========================================================

func _reset_selection() -> void:

	attack_mode = false
	cached_attack_tiles.clear()


	selected_unit = null
	pending_action_unit = null


	map.clear_selection()
	map.clear_hover_preview()


	preview_ui.hide_preview()


	action_menu.hide()


# =========================================================
# EXIT ATTACK MODE
# =========================================================

func _exit_attack_mode() -> void:

	attack_mode = false
	cached_attack_tiles.clear()


	map.clear_hover_preview()


# =========================================================
# PROCESS
# =========================================================

func _process(_delta: float) -> void:

	if not is_instance_valid(selected_unit):

		return


	# =====================================================
	# MODO ATAQUE
	# =====================================================
	#
	# MUITO IMPORTANTE:
	# Não chamamos clear_hover_preview() aqui.
	#
	# O modo ataque deve permanecer estável até o jogador
	# clicar em um alvo.
	# =====================================================

	if attack_mode:

		var mouse_pos: Vector2 = map.get_local_mouse_position()
		var grid: Vector2i = map.world_to_grid(mouse_pos)


		map.set_hovered_tile(grid)


		# =================================================
		# HOVER DO ATAQUE
		# =================================================

		if grid in cached_attack_tiles:

			map.show_hover_attack_tiles(
				[grid]
			)

		else:

			map.clear_hover_preview()


		# =================================================
		# COMBAT PREVIEW
		# =================================================

		var target: HeroUnit = (
			unit_manager.get_unit_at(grid)
		)


		if (
			is_instance_valid(target)
			and target.faction == Faction.Type.ENEMY
			and grid in cached_attack_tiles
		):

			var sim: Dictionary = (
				CombatResolver.simulate_attack(
					selected_unit,
					target
				)
			)

			preview_ui.show_preview(sim)

		else:

			preview_ui.hide_preview()


		return


	# =====================================================
	# MODO NORMAL
	# =====================================================

	var mouse_pos: Vector2 = map.get_local_mouse_position()
	var grid: Vector2i = map.world_to_grid(mouse_pos)


	map.set_hovered_tile(grid)


	# =====================================================
	# HOVER DE MOVIMENTO
	# =====================================================

	if map.is_tile_reachable(grid):

		var blocked: Array[Vector2i] = (
			unit_manager.get_occupied_tiles()
		)


		var path: Array[Vector2i] = (
			map.get_grid_path(
				selected_unit.grid_pos,
				grid,
				selected_unit,
				blocked
			)
		)


		map.show_preview_path(path)


		# =================================================
		# PREVIEW DE ATAQUE
		# =================================================

		var fake_reachable: Array[Vector2i] = [
			grid
		]


		var hover_attack_tiles: Array[Vector2i] = (
			map.compute_attack_tiles_from_movement(
				selected_unit,
				fake_reachable
			)
		)


		map.show_hover_attack_tiles(
			hover_attack_tiles
		)

	else:

		map.clear_hover_preview()


	# =====================================================
	# COMBAT PREVIEW NORMAL
	# =====================================================

	var unit: HeroUnit = (
		unit_manager.get_unit_at(grid)
	)


	if (
		is_instance_valid(unit)
		and unit.faction == Faction.Type.ENEMY
		and map.attack_tiles.has(grid)
	):

		var sim: Dictionary = (
			CombatResolver.simulate_attack(
				selected_unit,
				unit
			)
		)


		preview_ui.show_preview(sim)

	else:

		preview_ui.hide_preview()


# =========================================================
# CAN ATTACK
# =========================================================

func can_attack(
	attacker: HeroUnit,
	target: HeroUnit
) -> bool:

	if not is_instance_valid(attacker):
		return false


	if not is_instance_valid(target):
		return false


	if attacker.faction == target.faction:
		return false


	var dist: int = (
		map.grid_distance(
			attacker.grid_pos,
			target.grid_pos
		)
	)


	return (
		dist >= attacker.attack_range_min
		and
		dist <= attacker.attack_range_max
	)
