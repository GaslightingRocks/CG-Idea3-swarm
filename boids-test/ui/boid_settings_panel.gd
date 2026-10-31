class_name BoidSettingsPanel
extends CanvasLayer

## Debug UI that creates a slider for every @export_range property of a BoidSettings resource.
## The "toggle_settings" input action (H) shows or hides it.

# resource edited by the sliders, has to be set before the panel enters the tree
var settings: BoidSettings
# untouched instance used to restore the default values
var defaults: BoidSettings = BoidSettings.new()
var sliders: Dictionary[String, HSlider] = {}
var panel: PanelContainer
var list: VBoxContainer


func _ready() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(8, 8)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	list = VBoxContainer.new()
	margin.add_child(list)

	var title: Label = Label.new()
	title.text = "Boid Settings (H to hide)"
	list.add_child(title)

	# Builds one slider per range property, using the min/max/step from @export_range
	for property: Dictionary in settings.get_property_list():
		if not (property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE) or property["hint"] != PROPERTY_HINT_RANGE:
			continue
		var property_name: String = property["name"]
		var range_values: PackedStringArray = String(property["hint_string"]).split(",")
		var step: float = float(range_values[2]) if range_values.size() > 2 else 0.01
		sliders[property_name] = add_slider(
			property_name.capitalize(),
			float(range_values[0]),
			float(range_values[1]),
			step,
			settings.get(property_name),
			func(value: float) -> void: settings.set(property_name, value)
		)

	var reset_button: Button = Button.new()
	reset_button.text = "Reset to defaults"
	reset_button.pressed.connect(reset_to_defaults)
	list.add_child(reset_button)


func _unhandled_input(event: InputEvent) -> void:
	# "toggle_settings" is defined in Project Settings > Input Map (H by default)
	if event.is_action_pressed("toggle_settings"):
		panel.visible = not panel.visible


## Adds a labeled slider to the panel and calls on_changed whenever it is moved.
func add_slider(label_text: String, min_value: float, max_value: float, step: float, value: float, on_changed: Callable) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	list.add_child(row)

	var name_label: Label = Label.new()
	name_label.text = label_text
	name_label.custom_minimum_size.x = 170
	row.add_child(name_label)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = 180
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.text = format_value(value, step)
	value_label.custom_minimum_size.x = 48
	row.add_child(value_label)

	slider.value_changed.connect(func(new_value: float) -> void:
		value_label.text = format_value(new_value, step)
		on_changed.call(new_value)
	)
	return slider


## Moves every settings slider back to its default, which also updates the resource.
func reset_to_defaults() -> void:
	for property_name: String in sliders:
		sliders[property_name].value = defaults.get(property_name)


## Shows whole numbers without decimals and everything else with two.
func format_value(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(value))
	return "%.2f" % value
