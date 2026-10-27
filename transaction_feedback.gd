extends VBoxContainer

# Compatibility adapter for existing callers. Committed item/Coin changes are
# displayed once by FloatingFeedback; this node never creates a toast panel.
const GAIN_COLOR := Color("8df59b")
const LOSS_COLOR := Color("ffab70")
var text: String = ""
var popup_mode: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    hide()

func set_popup_mode(enabled: bool) -> void:
    popup_mode = enabled

func show_message(message: String) -> void:
    text = message
    hide()