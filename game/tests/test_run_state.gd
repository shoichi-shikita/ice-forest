extends SceneTree

var assert_count: int = 0
var failure_count: int = 0

func _init() -> void:
	var state_script = load("res://scripts/run_state.gd")
	if state_script == null:
		print("Failed to load res://scripts/run_state.gd")
		quit(1)
		return

	var state = state_script.new()

	print("Starting tests...")

	# Test initial state
	assert_eq(state.stamina, 100.0, "Initial stamina should be 100")
	assert_eq(state.escaped, false, "Should not be escaped initially")
	assert_eq(state.caught, false, "Should not be caught initially")
	assert_eq(state.is_finished(), false, "Should not be finished initially")
	assert_eq(state.can_escape(), false, "Should not be able to escape initially")

	# Test stamina bounds
	state.tick(1.0, false)
	assert_eq(state.stamina, 100.0, "Stamina should not exceed max")

	state.tick(10.0, true) # 200 stamina drain
	assert_eq(state.stamina, 0.0, "Stamina should not drop below 0")

	state.tick(-1.0, false) # Negative delta
	assert_eq(state.stamina, 0.0, "Negative delta should be ignored")

	state.tick(0.0, false) # Zero delta
	assert_eq(state.stamina, 0.0, "Zero delta should be ignored")

	state.tick(1.0, false)
	assert_eq(state.stamina, 12.0, "Stamina recovery")

	state.tick(0.5, true)
	assert_eq(state.stamina, 2.0, "Frame-rate independent stamina drain")

	# Test sigil collection
	assert_eq(state.collect_sigil(""), false, "Empty ID should be rejected")
	assert_eq(state.collect_sigil("alpha"), true, "Valid ID should be accepted")
	assert_eq(state.collect_sigil("alpha"), false, "Duplicate ID should be rejected")
	assert_eq(state.collect_sigil("beta"), true, "Second valid ID should be accepted")
	assert_eq(state.can_escape(), false, "Cannot escape with 2 sigils")
	assert_eq(state.collect_sigil("gamma"), true, "Third valid ID should be accepted")
	assert_eq(state.can_escape(), true, "Can escape with 3 sigils")
	assert_eq(state.collect_sigil("delta"), true, "Fourth valid ID should be accepted")

	# Test escape gate
	assert_eq(state.try_escape(), true, "Escape should succeed")
	assert_eq(state.escaped, true, "Escaped flag should be set")
	assert_eq(state.is_finished(), true, "State should be finished")

	# Test post-ending behavior
	state.catch_player()
	assert_eq(state.caught, false, "Cannot be caught after escaping")
	assert_eq(state.collect_sigil("epsilon"), false, "Cannot collect sigil after finishing")

	var pre_tick_stamina = state.stamina
	state.tick(1.0, false)
	assert_eq(state.stamina, pre_tick_stamina, "Stamina should not change after finishing")

	# Test reset and alternate ending
	state.reset()
	assert_eq(state.stamina, 100.0, "Stamina reset")
	assert_eq(state.collected.size(), 0, "Collections reset")
	assert_eq(state.escaped, false, "Escaped flag reset")
	assert_eq(state.caught, false, "Caught flag reset")

	state.catch_player()
	assert_eq(state.caught, true, "Caught flag set")
	assert_eq(state.is_finished(), true, "State finished")
	assert_eq(state.can_escape(), false, "Cannot escape if caught")

	state.collect_sigil("a")
	state.collect_sigil("b")
	state.collect_sigil("c")
	assert_eq(state.can_escape(), false, "Cannot escape if caught even with sigils")
	assert_eq(state.try_escape(), false, "Escape should fail if caught")

	print("%d assertions, %d failures" % [assert_count, failure_count])
	quit(0 if failure_count == 0 else 1)

func assert_eq(actual, expected, message: String) -> void:
	assert_count += 1
	if actual != expected:
		failure_count += 1
		print("Test failed: %s" % message)
		print("  Expected: %s" % str(expected))
		print("  Actual:   %s" % str(actual))
