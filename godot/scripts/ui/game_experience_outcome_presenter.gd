class_name GameExperienceOutcomePresenter
extends RefCounted

const StorybookUI = preload("res://scripts/ui/storybook_ui.gd")


func build_game_outcome(parent: Control, retry: bool, message: String, endless := false) -> Dictionary:
	var overlay := _modal_backdrop("GameOutcomeOverlay")
	overlay.z_index = 1500
	parent.add_child(overlay)
	var card := _modal_card(overlay, 0.08, 0.92, 0.23, 0.77)
	card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("3b1638") if retry else Color("123c4b"), Color("ff6f9b") if retry else Color("62e6b5"), 28))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 16)
	card.add_child(stack)
	var icon := Label.new()
	icon.text = "💔" if retry else "✨🦄✨"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 46)
	stack.add_child(icon)
	var title := _modal_title("RUN COMPLETE!" if endless else ("TRY AGAIN" if retry else "LEVEL COMPLETE!"))
	title.add_theme_color_override("font_color", Color("ffb2cf") if retry else Color("bffff1"))
	title.add_theme_font_size_override("font_size", 34)
	stack.add_child(title)
	var outcome_message := Label.new()
	outcome_message.name = "GameOutcomeMessage"
	outcome_message.text = message
	outcome_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outcome_message.add_theme_font_size_override("font_size", 21)
	outcome_message.add_theme_color_override("font_color", StorybookUI.CREAM)
	stack.add_child(outcome_message)
	var primary := Button.new()
	primary.name = "GameOutcomePrimaryAction"
	primary.text = "PLAY AGAIN" if endless else ("TRY AGAIN" if retry else "KEEP GOING")
	StorybookUI.apply_game_action(primary, 260)
	stack.add_child(primary)
	var category := Button.new()
	category.name = "GameOutcomeReturnToCategory"
	category.text = "RETURN TO CATEGORY"
	StorybookUI.apply_game_action(category, 260)
	stack.add_child(category)
	return {"overlay": overlay, "primary": primary, "category": category}


func build_sparkle_retry(parent: Control, failure_reason: String) -> Dictionary:
	var overlay := _modal_backdrop("SecondSparkleRetryOverlay")
	overlay.z_index = 1550
	parent.add_child(overlay)
	var card := _modal_card(overlay, 0.08, 0.92, 0.22, 0.78)
	card.name = "SecondSparkleRetryCard"
	card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(Color("32194a"), StorybookUI.GOLD_BRIGHT, 28))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	card.add_child(stack)
	var icon := Label.new()
	icon.text = "✨  🦄  ✨"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 44)
	stack.add_child(icon)
	var title := _modal_title("SECOND SPARKLE!")
	title.add_theme_color_override("font_color", Color("ffe7a6"))
	title.add_theme_font_size_override("font_size", 32)
	stack.add_child(title)
	var reason := Label.new()
	reason.name = "SecondSparkleFailureReason"
	reason.text = failure_reason if not failure_reason.strip_edges().is_empty() else "This try came to an end."
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reason.add_theme_font_size_override("font_size", 20)
	reason.add_theme_color_override("font_color", Color("ffd1e5"))
	stack.add_child(reason)
	var explanation := Label.new()
	explanation.name = "SecondSparkleExplanation"
	explanation.text = "Sparkle saved one FREE RETRY for you. Tap CONTINUE to restart this same level. This one-time retry is now used."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", 21)
	explanation.add_theme_color_override("font_color", StorybookUI.CREAM)
	stack.add_child(explanation)
	var continue_button := Button.new()
	continue_button.name = "SecondSparkleContinue"
	continue_button.text = "CONTINUE"
	StorybookUI.apply_game_action(continue_button, 260)
	stack.add_child(continue_button)
	return {"overlay": overlay, "continue_button": continue_button}


func _modal_backdrop(node_name: String) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = node_name
	overlay.color = Color(0.02, 0.03, 0.10, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 1000
	return overlay


func _modal_card(parent: Control, left: float, right: float, top: float, bottom: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.anchor_left = left
	card.anchor_right = right
	card.anchor_top = top
	card.anchor_bottom = bottom
	card.add_theme_stylebox_override("panel", StorybookUI.plaque_style(StorybookUI.CREAM, StorybookUI.GOLD, 24))
	parent.add_child(card)
	return card


func _modal_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 27)
	label.add_theme_color_override("font_color", Color("9c356d"))
	return label
