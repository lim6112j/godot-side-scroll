# class_name을 붙이지 않는다: Godot는 오토로드 싱글톤과 같은 이름의 class_name을
# "hides an autoload singleton" 파싱 오류로 거부한다 (Engine rule 3). 오토로드
# 이름 자체가 전역 식별자이므로, class_name 없이도 LevelRegistry.get_level()
# 처럼 접근한다.
extends Node

# 레벨 목록 (설계 8장). LevelData 리소스를 인덱스로 찾아준다. 레벨을 추가하려면
# resources/levels/ 에 level_%d.tres 를 하나 더 넣고 level_count() 를 고친다.

const LEVEL_DIR := "res://resources/levels/"
const LEVEL_COUNT := 5

func level_count() -> int:
    return LEVEL_COUNT


func get_level(index: int) -> LevelData:
    if index < 1 or index > level_count():
        return null
    return load(LEVEL_DIR + "level_%d.tres" % index) as LevelData
