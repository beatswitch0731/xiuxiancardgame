extends Control

# A lightweight 2D projection of the browser's ambient spiritual particles.
# It sits behind every decision surface and never owns gameplay state.
const COUNTS := {"low": 80, "balanced": 210, "high": 380}
const OPACITIES := {"low": 0.24, "balanced": 0.44, "high": 0.60}
const SPEEDS := {"low": 0.35, "balanced": 0.70, "high": 1.0}
const PHASE_COLORS := {
	"CALM": Color("39d0d8"), "BUILDUP": Color("c19a6b"),
	"TENSION": Color("4a4e69"), "CLIMAX": Color("800020"),
	"RESOLUTION": Color("a371f7"),
}
const PHASE_SPEEDS := {"CALM": 0.6, "BUILDUP": 1.2,
	"TENSION": 2.0, "CLIMAX": 5.0, "RESOLUTION": 0.8}

var quality := "high"
var steady_camera := false
var phase := "CALM"
var elapsed := 0.0
var _redraw_clock := 0.0
var _points: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var random := RandomNumberGenerator.new()
	random.seed = 20470627
	for _index in COUNTS.high:
		_points.append(Vector3(random.randf(), random.randf(), random.randf()))
	queue_redraw()


func configure(next_quality: String, next_steady: bool) -> void:
	quality = next_quality if COUNTS.has(next_quality) else "balanced"
	steady_camera = next_steady
	queue_redraw()


func set_phase(next_phase: String) -> void:
	var resolved := next_phase if PHASE_COLORS.has(next_phase) else "CALM"
	if phase != resolved:
		phase = resolved
		queue_redraw()


func particle_count() -> int:
	return COUNTS[quality]


func breath_scale() -> float:
	return 1.0 if steady_camera else 1.0 + sin(elapsed * 0.5) * 0.05


func _process(delta: float) -> void:
	elapsed += delta
	_redraw_clock += delta
	var interval := 1.0 / (60.0 if quality == "high" else 30.0)
	if _redraw_clock >= interval:
		_redraw_clock = fmod(_redraw_clock, interval)
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center := size * 0.5
	var scale_now := breath_scale()
	var drift: float = elapsed * 0.008 * float(SPEEDS[quality]) * \
		float(PHASE_SPEEDS[phase])
	var tint: Color = PHASE_COLORS[phase]
	for index in particle_count():
		var point: Vector3 = _points[index]
		var position := Vector2(fposmod(point.x + drift * (0.4 + point.z), 1.0),
			fposmod(point.y - drift * (0.3 + point.z), 1.0)) * size
		position = center + (position - center) * scale_now
		var alpha: float = float(OPACITIES[quality]) * (0.12 + 0.18 * point.z)
		draw_circle(position, 0.7 + point.z * 1.1,
			Color(tint.r, tint.g, tint.b, alpha))
