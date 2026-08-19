extends StyleBox
class_name PlaqueStyleBox
## Custom-drawn "carved wooden signboard" stylebox: chamfered corners, a
## shallow V-notch top/bottom, a bronze/gold frame, and small corner rivets.
## Matches the hand-painted wooden plaque reference art. Used by PrimaryButton
## / SecondaryButton in place of a plain rounded StyleBoxFlat, since that
## silhouette can't be produced with rounded corners alone.

@export var wood_color: Color = Color(0.235, 0.161, 0.106)
@export var border_color: Color = Color(0.851, 0.651, 0.161)
@export var bevel_color: Color = Color(0.45, 0.32, 0.12)
@export var rivet_color: Color = Color(0.62, 0.44, 0.16)
@export var shadow_color: Color = Color(0, 0, 0, 0.5)
@export var border_width: float = 5.0
@export var chamfer: float = 15.0       # corner cut size
@export var notch: float = 8.0          # depth of the top/bottom center notch
@export var rivet_radius: float = 4.0
@export var content_margin_h: float = 28.0
@export var content_margin_v: float = 14.0


func _get_minimum_size() -> Vector2:
	return Vector2(chamfer * 2.0, chamfer * 1.5)


func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect


func _get_content_margin(side: int) -> float:
	if side == 0 or side == 2:
		return content_margin_h
	return content_margin_v


func _plaque_points(rect: Rect2, inset: float) -> PackedVector2Array:
	var r := rect.grow(-inset)
	var c: float = max(chamfer - inset * 0.6, 2.0)
	var n: float = max(notch - inset * 0.4, 0.0)
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.position.x + r.size.x
	var y1 := r.position.y + r.size.y
	var mx := r.position.x + r.size.x * 0.5

	return PackedVector2Array([
		Vector2(x0 + c, y0),
		Vector2(mx - c, y0),
		Vector2(mx, y0 + n),
		Vector2(mx + c, y0),
		Vector2(x1 - c, y0),
		Vector2(x1, y0 + c),
		Vector2(x1, y1 - c),
		Vector2(x1 - c, y1),
		Vector2(mx + c, y1),
		Vector2(mx, y1 - n),
		Vector2(mx - c, y1),
		Vector2(x0 + c, y1),
		Vector2(x0, y1 - c),
		Vector2(x0, y0 + c),
	])


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# Drop shadow: same silhouette, offset down-right, soft dark fill.
	var shadow_rect := Rect2(rect.position + Vector2(0, 3), rect.size)
	var shadow_pts := _plaque_points(shadow_rect, 0.0)
	var shadow_colors := PackedColorArray()
	shadow_colors.resize(shadow_pts.size())
	shadow_colors.fill(shadow_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, shadow_pts, shadow_colors)

	# Outer bronze/gold frame.
	var outer := _plaque_points(rect, 0.0)
	var border_colors := PackedColorArray()
	border_colors.resize(outer.size())
	border_colors.fill(border_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, outer, border_colors)

	# Inner darker bevel ring, between the outer frame and the wood fill --
	# this is what gives it "layered frame" depth instead of one flat border.
	var bevel_w: float = border_width * 0.4
	var bevel := _plaque_points(rect, bevel_w)
	var bevel_colors := PackedColorArray()
	bevel_colors.resize(bevel.size())
	bevel_colors.fill(bevel_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, bevel, bevel_colors)

	# Dark wood center.
	var inner := _plaque_points(rect, border_width)
	var fill_colors := PackedColorArray()
	fill_colors.resize(inner.size())
	fill_colors.fill(wood_color)
	RenderingServer.canvas_item_add_polygon(to_canvas_item, inner, fill_colors)

	# Faint plank-seam grain: thin semi-transparent rects clipped to the
	# wood fill's bounding box (safe -- no line-cap rendering quirks).
	var grain_area := rect.grow(-(border_width + bevel_w + 4.0))
	if grain_area.size.y > 24.0:
		var grain_color := wood_color.darkened(0.3)
		grain_color.a = 0.4
		var rows: int = max(int(grain_area.size.y / 11.0), 2)
		for i in range(1, rows):
			var gy: float = grain_area.position.y + grain_area.size.y * float(i) / float(rows)
			var seam := Rect2(grain_area.position.x, gy, grain_area.size.x, 1.0)
			RenderingServer.canvas_item_add_rect(to_canvas_item, seam, grain_color)

	# Thin bright highlight along the very top inner edge, like light
	# catching a metal bevel.
	var hl_color := border_color.lightened(0.35)
	hl_color.a = 0.5
	var hl_rect := Rect2(rect.position.x + chamfer, rect.position.y + 2.0, rect.size.x - chamfer * 2.0, 1.5)
	RenderingServer.canvas_item_add_rect(to_canvas_item, hl_rect, hl_color)

	# Corner rivets, inset from each chamfered corner.
	var pad := chamfer * 0.55 + border_width * 0.5
	var positions := [
		rect.position + Vector2(pad, pad),
		rect.position + Vector2(rect.size.x - pad, pad),
		rect.position + Vector2(pad, rect.size.y - pad),
		rect.position + Vector2(rect.size.x - pad, rect.size.y - pad),
	]
	for p: Vector2 in positions:
		RenderingServer.canvas_item_add_circle(to_canvas_item, p, rivet_radius + 1.0, bevel_color.darkened(0.3))
		RenderingServer.canvas_item_add_circle(to_canvas_item, p, rivet_radius, rivet_color)
		RenderingServer.canvas_item_add_circle(to_canvas_item, p + Vector2(-0.8, -0.8), rivet_radius * 0.4, rivet_color.lightened(0.4))
