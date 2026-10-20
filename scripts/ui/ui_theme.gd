extends RefCounted
## UITheme — builds the cozy parchment-and-wood UI theme entirely in code,
## plus small widget helpers used by every panel.

const PARCHMENT := Color("f6ead0")
const PARCHMENT_D := Color("ead8b2")
const INK := Color("4a3020")
const INK_SOFT := Color("7a5a40")
const WOOD := Color("7a4a2a")
const WOOD_D := Color("4f2f1a")
const GREEN := Color("8cc45a")
const GREEN_D := Color("4f7a2a")
const GOLD := Color("ffd45a")
const DARK := Color(0.12, 0.09, 0.07, 0.86)


static func box(bg: Color, border: Color, bw: int = 3, pad: int = 8, radius: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.anti_aliasing = false
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 17
	var panel := box(PARCHMENT, WOOD, 4, 14, 4)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(0, 4)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", INK)
	# Buttons
	t.set_stylebox("normal", "Button", box(GREEN, GREEN_D, 3, 7))
	t.set_stylebox("hover", "Button", box(GREEN.lightened(0.15), GREEN_D, 3, 7))
	t.set_stylebox("pressed", "Button", box(GREEN.darkened(0.15), GREEN_D, 3, 7))
	t.set_stylebox("disabled", "Button", box(Color("c8c0b0"), Color("8a8070"), 3, 7))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color("26381a"))
	t.set_color("font_hover_color", "Button", Color("1a2a10"))
	t.set_color("font_pressed_color", "Button", Color("1a2a10"))
	t.set_color("font_focus_color", "Button", Color("26381a"))
	t.set_color("font_disabled_color", "Button", Color("7a7060"))
	# Progress bars
	t.set_stylebox("background", "ProgressBar", box(Color("5a4030"), WOOD_D, 2, 0, 3))
	t.set_stylebox("fill", "ProgressBar", box(Color("8cd45a"), Color("5a9a3a"), 2, 0, 3))
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	t.set_constant("outline_size", "ProgressBar", 3)
	t.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.6))
	# Scrollbars
	t.set_stylebox("scroll", "VScrollBar", box(PARCHMENT_D, PARCHMENT_D, 0, 4, 3))
	t.set_stylebox("grabber", "VScrollBar", box(WOOD, WOOD, 0, 4, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(WOOD.lightened(0.2), WOOD, 0, 4, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(WOOD_D, WOOD, 0, 4, 3))
	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", box(PARCHMENT, WOOD, 2, 6))
	t.set_color("font_color", "TooltipLabel", INK)
	return t


static func label(text: String, size: int = 17, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func outlined(text: String, size: int = 18, color: Color = Color.WHITE) -> Label:
	var l := label(text, size, color)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.05, 0.9))
	return l


static func icon_rect(tex: Texture2D, px: int = 48) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(cb)
	return b


static func card(bg: Color = PARCHMENT, border: Color = WOOD, pad: int = 10, bw: int = 3) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, bw, pad))
	return p


static func dark_card(pad: int = 8) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(DARK, Color(0.35, 0.25, 0.15, 0.9), 2, pad, 4)
	p.add_theme_stylebox_override("panel", s)
	return p


static func hsep(h: int = 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func rarity_text(r: int) -> String:
	return ItemDB.RARITY_NAMES[r]


static func rarity_color(r: int) -> Color:
	return ItemDB.RARITY_COLORS[r]


## Item slot with icon, rarity frame and optional count.
static func slot(key: String, count: int = -1, size: int = 56, state: int = 2) -> PanelContainer:
	var r := ItemDB.rarity_of(key)
	var border: Color = ItemDB.RARITY_COLORS[r].darkened(0.25) if state >= 2 else Color("b8a888")
	var p := card(PARCHMENT_D if state >= 2 else Color("ddd0b4"), border, 2, 3)
	p.custom_minimum_size = Vector2(size, size)
	var ir := icon_rect(PixelArt.icon(key), size - 10)
	if state == 0:
		ir.modulate = Color(0, 0, 0, 0.28)
	elif state == 1:
		ir.modulate = Color(0.25, 0.22, 0.2, 0.7)
	p.add_child(ir)
	if count >= 0:
		var c := outlined(str(count), 14)
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		c.size_flags_vertical = Control.SIZE_SHRINK_END
		c.size_flags_horizontal = Control.SIZE_SHRINK_END
		p.add_child(c)
	p.tooltip_text = ItemDB.display_name(key) if state > 0 else "???"
	return p


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
