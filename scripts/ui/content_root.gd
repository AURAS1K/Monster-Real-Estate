extends Control
## Wrapper used by Settings/Credits/How To Play panels so their CloseButton
## can be anchored independently of the PanelContainer (which would otherwise
## force every direct child to fill the same full rect, ignoring anchors).
##
## Plain Control does not report its children's minimum size to its parent,
## so without this override the parent PanelContainer ("Card") collapses to
## a near-zero rect instead of sizing to fit the real content (the "Box").
## This just forwards Box's combined minimum size upward so layout works
## exactly as it did before ContentRoot was introduced.

func _get_minimum_size() -> Vector2:
	var box: Control = get_node_or_null("Box")
	if box:
		return box.get_combined_minimum_size()
	return Vector2.ZERO
