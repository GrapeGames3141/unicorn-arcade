extends Node

const Policy := preload("res://scripts/platform/child_ads_policy.gd")
var failures: Array[String] = []

class LegacyNativeStub extends RefCounted:
	signal on_initialization_complete(status: Dictionary)
	var calls: Array[String] = []
	var request: Dictionary = {}
	var listener_connected_before_initialize := false
	func set_request_configuration(config: Dictionary, _devices: Array[String]) -> void:
		calls.append("configure")
		request = config.duplicate()
	func initialize() -> void:
		calls.append("initialize")
		listener_connected_before_initialize = not get_signal_connection_list("on_initialization_complete").is_empty()
		on_initialization_complete.emit({})


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Policy.permits_ads({}), "safe defaults remain child-directed G")
	for invalid in [{"child_directed": false}, {"child_directed": "true"},
		{"max_ad_content_rating": "PG"}, {"max_ad_content_rating": "T"},
		{"max_ad_content_rating": "MA"}, {"max_ad_content_rating": ""},
		{"max_ad_content_rating": true}, {"child_directed": null}]:
		_check(not Policy.permits_ads(invalid), "unsafe configuration fails closed: %s" % invalid)
	var original_config: Dictionary = AdBarService.config().duplicate(true)
	AdBarService.set("_config", {"ads_enabled": true, "child_directed": false})
	_check(not AdBarService.ads_enabled(), "service blocks unsafe child treatment")
	AdBarService.set("_config", {"ads_enabled": true, "max_ad_content_rating": "T"})
	_check(not AdBarService.ads_enabled(), "service blocks widened inventory")
	AdBarService.set("_config", {"ads_enabled": true, "child_directed": true, "max_ad_content_rating": "G"})
	_check(AdBarService.ads_enabled(), "service permits safe configuration")
	AdBarService.set("_config", original_config)
	var native := LegacyNativeStub.new()
	var original_plugin: Object = MobileAds._plugin
	var original_listener := MobileAds._current_on_initialization_complete_listener
	var completed := [false]
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus): completed[0] = true
	MobileAds._plugin = native
	MobileAds.initialize(listener, Policy.request_configuration())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(native.calls == ["configure", "initialize"], "native configuration precedes the very first initialization")
	_check(native.request.get("tag_for_child_directed_treatment") == 1, "native boundary receives TFCD TRUE")
	_check(native.request.get("tag_for_under_age_of_consent") == -1, "native boundary avoids simultaneous TFUA TRUE")
	_check(native.request.get("max_ad_content_rating") == "G", "native boundary receives max G")
	_check(native.listener_connected_before_initialize and completed[0], "even immediate native completion reaches the listener")
	MobileAds._plugin = original_plugin
	MobileAds._current_on_initialization_complete_listener = original_listener
	if failures.is_empty():
		print("CHILD_ADS_POLICY_OK: unsafe configs blocked; native boundary TFCD=1, TFUA=-1, max=G before initialization")
		get_tree().quit(0)
	else:
		push_error("Child ads policy failed: %s" % "; ".join(failures))
		get_tree().quit(1)
