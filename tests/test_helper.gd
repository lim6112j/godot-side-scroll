class_name TestHelper
extends RefCounted

var failures: Array[String] = []
var total: int = 0
var section_counts: Dictionary = {}
var _section: String = ""

func section(name: String) -> void:
    _section = _suite_name(name)

# Suites are auto-discovered by filename (`test_<name>.gd`), but reports use the
# short name (`<name>`) so output matches the documented notation.
func _suite_name(name: String) -> String:
    var short := name
    if short.begins_with("test_"):
        short = short.substr(5)
    if short.ends_with(".gd"):
        short = short.substr(0, short.length() - 3)
    return short

func check(condition: bool, name: String) -> void:
    total += 1
    section_counts[_section] = int(section_counts.get(_section, 0)) + 1
    if not condition:
        failures.append("%s :: %s" % [_section, name])

func approx(a: float, b: float, tolerance: float, name: String) -> void:
    check(absf(a - b) <= tolerance, "%s (기대 %f, 실제 %f)" % [name, b, a])

func step_frames(tree: SceneTree, count: int) -> void:
    for _i in count:
        await tree.physics_frame

func passed() -> bool:
    return failures.is_empty()

func summary() -> String:
    var detail := ""
    for s in section_counts:
        detail += "\n  %s: %d" % [s, section_counts[s]]
    if passed():
        return "ALL %d CHECKS PASSED%s" % [total, detail]
    var lines := "FAILED %d of %d CHECKS:%s" % [failures.size(), total, detail]
    for f in failures:
        lines += "\n  FAIL: " + f
    return lines
