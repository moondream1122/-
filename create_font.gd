extends SceneTree

func _init():
    var font = FontFile.new()
    font.font_name = "NotoSansCJK"
    font.data = FileAccess.get_file_as_bytes("res://fonts/NotoSansCJK-Regular.otf")
    var err = ResourceSaver.save(font, "res://fonts/chinese_font.tres")
    print("Save error: ", errtoSansCJK-Regular.otf")
    var err = ResourceSaver.save(font, "res://fonts/chinese_font.tres")
    print("Save error: ", err)
    quit()