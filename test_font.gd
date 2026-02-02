extends SceneTree

func _init():
    var data = FileAccess.get_file_as_bytes("res://fonts/NotoSansCJK-Regular.otf")
    print("Data size: ", data.size())
    if data.size() > 0:
        var font = FontFile.new()
        font.data = data
        var err = ResourceSaver.save(font, "res://fonts/chinese_font.tres")
        print("Save error: ", err)
    quit()