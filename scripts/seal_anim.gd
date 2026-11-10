class_name SealAnim
extends Node

@onready var _player: AnimationPlayer = $AnimationPlayer

func play(name: String) -> void:
    if has(name):
        _player.play(name)


func current() -> String:
    return _player.current_animation


func has(name: String) -> bool:
    return _player.has_animation(name)
