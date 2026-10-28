extends RefCounted
class_name ForestRunState

const MAX_STAMINA: float = 100.0
const REQUIRED_SIGILS: int = 3

var stamina: float = MAX_STAMINA
var collected: Dictionary = {}
var escaped: bool = false
var caught: bool = false

func reset() -> void:
	stamina = MAX_STAMINA
	collected.clear()
	escaped = false
	caught = false

func is_finished() -> bool:
	return escaped or caught

func tick(delta: float, sprinting: bool) -> void:
	if delta <= 0.0 or is_finished():
		return

	if sprinting:
		stamina -= 20.0 * delta
	else:
		stamina += 12.0 * delta

	stamina = clampf(stamina, 0.0, MAX_STAMINA)

func collect_sigil(id: String) -> bool:
	if is_finished() or id.is_empty() or collected.has(id):
		return false
	collected[id] = true
	return true

func can_escape() -> bool:
	return collected.size() >= REQUIRED_SIGILS and not caught

func try_escape() -> bool:
	if can_escape():
		escaped = true
		return true
	return false

func catch_player() -> void:
	if not escaped:
		caught = true
