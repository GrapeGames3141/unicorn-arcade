#!/usr/bin/env bash
# Run the explicit headless Godot test manifest used by the CI gate.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$ROOT/godot"
export GODOT_CI_ROOT="$ROOT"
export GODOT_PROJECT="$PROJECT"
# shellcheck source=install-godot.sh
source "$ROOT/scripts/ci/install-godot.sh"

echo "=== Android build-template cache contract ==="
bash "$ROOT/scripts/ci/test-android-template-cache.sh"

install_godot

TEST_TIMEOUT_SECONDS="${GODOT_TEST_TIMEOUT_SECONDS:-180}"
IMPORT_TIMEOUT_SECONDS="${GODOT_IMPORT_TIMEOUT_SECONDS:-2700}"


bootstrap_godot_project() {
	echo "=== Godot project import/bootstrap ==="
	# --import exits after generating asset imports and global_script_class_cache,
	# so a cold checkout gets the same project-aware type metadata as a warm one.
	timeout --foreground --kill-after=20s "${IMPORT_TIMEOUT_SECONDS}s" \
		godot --headless --path "$PROJECT" --editor --import
	[[ -s "$PROJECT/.godot/global_script_class_cache.cfg" ]] || {
		echo "ERROR: Godot import did not create global_script_class_cache.cfg" >&2
		exit 1
	}
}


run_godot_test() {
	local label="$1"
	shift
	echo "=== ${label} ==="
	timeout --foreground --kill-after=20s "${TEST_TIMEOUT_SECONDS}s" \
		godot --headless --path "$PROJECT" "$@"
}


bootstrap_godot_project

# Keep this manifest explicit: new scene suites must be deliberately added to CI.
run_godot_test "App-owned GDScript parse smoke" res://tests/parse_app_scripts.tscn
run_godot_test "Parity rule tests" --script res://tests/run_tests.gd
run_godot_test "PR31 project-aware dead-code audit" res://tests/dead_code_audit_pr31.tscn

# The historical aggregate mounts many live SubViewport scene trees in one
# process. Pinned Godot 4.7.1 headless on both Linux CI and Windows hits a
# repeated-Room-Editor SubViewport crash: an unbounded "Object was deleted
# while awaiting a callback" flood. Keep it available for explicit desktop
# stress diagnosis only. Its assertions are superseded in this gate by the
# entries below: runtime_word_suite (all Word modes), runtime_number_suite
# (number games plus Galaxy), runtime_meta_suite (Room Editor roam/rebuild),
# runtime_shell_suite (routing), runtime_main_shell_integration,
# runtime_marketplace_integration, runtime_profile_integration, and
# runtime_refactor_integration (live Room decor previews); the focused Galaxy,
# ad-layout, sliding-window, header, and jump entries cover their named scopes.
if [[ "${RUN_MONOLITHIC_RUNTIME_INTEGRATION:-0}" == "1" ]]; then
	run_godot_test "Runtime integration stress aggregate" res://tests/runtime_integration.tscn
else
	echo "=== Runtime integration stress aggregate: skipped (set RUN_MONOLITHIC_RUNTIME_INTEGRATION=1 to run) ==="
fi

for scene in \
	runtime_main_shell_integration \
	runtime_marketplace_integration \
	runtime_gameplay_correctness_integration \
	runtime_polish_integration \
	runtime_companion_polish_integration \
	runtime_furniture_polish_integration \
	store1_model_integration \
	store_model_catalog_integration \
	runtime_level_run_integration \
	runtime_level_run_batch_two_integration \
	runtime_level_run_batch_three_integration \
	runtime_outcome_transition_integration \
	runtime_profile_integration \
	runtime_persistence_integration \
	runtime_refactor_integration; do
	run_godot_test "Runtime integration: ${scene}" "res://tests/${scene}.tscn"
done

for suite in runtime_word_suite runtime_number_suite runtime_meta_suite runtime_shell_suite; do
	run_godot_test "Bounded runtime suite: ${suite}" "res://tests/${suite}.tscn"
done

for scene in \
	galaxy_pause_opening_test \
	ad_layout_integration \
	sliding_window_scope_test \
	unicorn_header_scope_test \
	unicorn_jump_layout_test; do
	run_godot_test "Focused scope/layout test: ${scene}" "res://tests/${scene}.tscn"
done

echo "GODOT_TEST_MANIFEST_OK"
