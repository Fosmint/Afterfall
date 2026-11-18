class_name UIThemeHelper
extends RefCounted

# Единый стиль постапокалиптического мобильного интерфейса Afterfall
const COL_BG := Color(0.11, 0.13, 0.12, 0.94)
const COL_CARD := Color(0.16, 0.19, 0.17, 0.95)
const COL_BORDER := Color(0.36, 0.41, 0.35, 0.9)
const COL_ACCENT := Color(0.78, 0.49, 0.24, 1.0)
const COL_ACCENT_HOVER := Color(0.88, 0.58, 0.31, 1.0)
const COL_TEXT := Color(0.91, 0.90, 0.85, 1.0)
const COL_MUTED := Color(0.66, 0.68, 0.63, 1.0)

static func make_panel_style(bg: Color = COL_BG, border: Color = COL_BORDER, radius: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func style_button(btn: Button, accent: bool = false, font_size: int = 17) -> void:
	var normal := make_panel_style(
		COL_ACCENT if accent else Color(0.20, 0.24, 0.21, 0.95),
		Color(0.95, 0.72, 0.42, 0.9) if accent else COL_BORDER,
		8
	)
	var pressed := make_panel_style(
		COL_ACCENT.darkened(0.2) if accent else Color(0.14, 0.17, 0.15, 0.98),
		COL_ACCENT,
		8
	)
	var disabled := make_panel_style(Color(0.14, 0.15, 0.14, 0.6), Color(0.26, 0.28, 0.26, 0.5), 8)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color(0.48, 0.5, 0.47, 0.8))
	btn.add_theme_font_size_override("font_size", font_size)

static func make_bar_style(fill_col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill_col
	sb.set_corner_radius_all(4)
	return sb

static func make_bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.08, 0.85)
	sb.border_color = Color(0.28, 0.31, 0.28, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	return sb
