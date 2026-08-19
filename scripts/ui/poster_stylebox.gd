extends StyleBox
class_name PosterStyleBox
## Custom-drawn "pinned parchment poster" stylebox: chamfered corners, a
## thin ink border, faint fiber lines, and one or two small bronze pin
## studs at the top edge. Sibling to PlaqueStyleBox (same chamfered-
## polygon + corner-stud technique) but tuned for paper instead of wood:
## no center notch, no plank grain, lighter/thinner frame. Used by the
## Request Board's poster-card buttons (normal/hover/pressed/disabled
## give each selection state its own tint, per UITheme's PosterButton
## variation) so individual requests read as physical pinned documents.

@export var parchment_color: Color = Color(0.867, 0.796, 0.647)
@export var border_color: Color = Color(0.329, 0.212, 0.129)
@export var pin_color: Color = Color(0.62, 0.44, 0.16)
@export var shadow_color: Color = Color(0, 0, 0, 0.35)
@export var glow_color: Color = Color(1.0, 0.82, 0.4, 0.0)  # a=0 -> no glow
@export var border_width: float = 2.0
@export var chamfer: float = 10.0
@export var pin_radius: float = 3.5
@export var pin_count: int = 1  # 1 = single top-center pin, 2 = top corners
@export var content_margin_h: float = 14.0
@export var content_margin_v: float = 10.0


func _get_minimum_size() -> Vector2:
	return Vector2(chamfer * 2.0, chamfer * 2.0)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect


func _get_content_margin(side: int) -> float:
	if side == 0 or side == 2:
		return content_margin_h
	return content_margin_v


func _poster_points(rect: Rect2, inset: float) -> PackedVector2Array:
	var r := rect.grow(-inset)
	var c: float = max(chamfer - inset * 0.5, 2.0)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.position.x + r.size.x
	var y1 := r.position.y + r.size.y
	return PackedVector2Array([
		Vector2(x0 + c, y0),
		Vector2(x1 - c, y0),
		Vector2(x1, y0 + c),
		Vector2(x1, y1 - c),
		Vector2(x1 - c, y1),
		Vector2(x0 + c, y1),
		Vector2(x0, y1 - c),
		Vector2(x0, y0 + c),
	])


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# Soft glow behind the poster (selected state only -- alpha 0 elsewhere).
	if glow_color.a > 0.0:
		var glow_rect := rect.grow(4.0)
		var glow_pts := _poster_points(glow_rect, 0.0)
		var glow_colors := PackedColorArray()
		glow_colors.resize(glow_pts.size())
		glow_colors.fill(glow_color)
		RenderingServer.canvas_item_add_polygon(to_canvas_item, glow_pts, glow_colors)

	# Drop shadow.
	var shadow_rect := Rect2(rect.position + Vector2(0, 3), rect.size)
	var shadow_pts := _poster_points(shadow_rect, 0.0)
	var shadow_colors := PackedColorArray()
	shadow_colors.resize(shadow_pts.size())
	shadow_colors.fill(shadow_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, shadow_pts, shadow_colors)

	# Thin ink border.
	var outer := _poster_points(rect, 0.0)
	var border_colors := PackedColorArray()
	border_colors.resize(outer.size())
	border_colors.fill(border_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, outer, border_colors)

	# Parchment fill.
	var inner := _poster_points(rect, border_width)
	var fill_colors := PackedColorArray()
	fill_colors.resize(inner.size())
	fill_colors.fill(parchment_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, inner, fill_colors)

	# Faint horizontal fiber lines -- just enough texture to not read as a
	# flat modern card fill.
	var fiber_area := rect.grow(-(border_width + 5.0))
	if fiber_area.size.y > 20.0:
		var fiber_color := parchment_color.darkened(0.12)
		fiber_color.a = 0.35
		var rows: int = max(int(fiber_area.size.y / 9.0), 2)
		for i in range(1, rows):
			var fy: float = fiber_area.position.y + fiber_area.size.y * float(i) / float(rows)
			var seam := Rect2(fiber_area.position.x, fy, fiber_area.size.x, 1.0)
			RenderingServer.canvas_item_add_rect(to_canvas_item, seam, fiber_color)

	# Pin stud(s) along the top edge.
	var pin_positions: Array[Vector2] = []
	if pin_count >= 2:
		var pad := chamfer * 0.6 + border_width
		pin_positions.append(rect.position + Vector2(pad, pad * 0.85))
		pin_positions.append(rect.position + Vector2(rect.size.x - pad, pad * 0.85))
	else:
		pin_positions.append(Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + chamfer * 0.55 + border_width))
	for p: Vector2 in pin_positions:
		RenderingServer.canvas_item_add_circle(to_canvas_item, p, pin_radius + 1.3, border_color.darkened(0.2))
		RenderingServer.canvas_item_add_circle(to_canvas_item, p, pin_radius, pin_color)
		RenderingServer.canvas_item_add_circle(to_canvas_item, p + Vector2(-0.7, -0.7), pin_radius * 0.4, pin_color.lightened(0.5))
