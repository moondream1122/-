extends SceneTree

func _init():
    var font = FontFile.new()
    font.load_dynamic_font("res://fonts/NotoSansCJK-Regular.otf")
    ResourceSaver.save(font, "res://fonts/chinese_font.tres")
    quit()