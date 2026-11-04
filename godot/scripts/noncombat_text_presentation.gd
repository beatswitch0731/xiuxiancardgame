extends RefCounted

# src/core/TextPresentation.js::normalizeNarrativeText for authored UI copy.
static func normalize(value: Variant) -> String:
	var result := "" if value == null else str(value)
	result = result.replace("\\r\\n", "\n").replace("\\n", "\n") \
		.replace("\r\n", "\n").replace("\r", "\n")
	while result.contains("\n\n\n"):
		result = result.replace("\n\n\n", "\n\n")
	return result.strip_edges()
