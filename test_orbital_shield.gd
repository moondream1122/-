extends SceneTree

func _init():
    print("=== 軌道護盾修復測試開始 ===")

    # 創建測試場景
    var test_scene = Node2D.new()
    test_scene.name = "TestScene"

    # 模擬_ready函數中的重置邏輯
    reset_orbital_shields(test_scene)

    # 測試軌道護盾升級
    print("測試軌道護盾升級...")

    # 第一次升級
    orbital_shield_upgrade(test_scene)
    print("軌道護盾等級: ", test_scene.get_meta("orbital_shield_level"))
    print("軌道護盾數量: ", test_scene.get_meta("orbital_shields").size())

    # 第二次升級
    orbital_shield_upgrade(test_scene)
    print("軌道護盾等級: ", test_scene.get_meta("orbital_shield_level"))
    print("軌道護盾數量: ", test_scene.get_meta("orbital_shields").size())

    # 第三次升級
    orbital_shield_upgrade(test_scene)
    print("軌道護盾等級: ", test_scene.get_meta("orbital_shield_level"))
    print("軌道護盾數量: ", test_scene.get_meta("orbital_shields").size())

    # 測試重置
    print("\n測試重置...")
    reset_orbital_shields(test_scene)
    print("重置後軌道護盾等級: ", test_scene.get_meta("orbital_shield_level") if test_scene.has_meta("orbital_shield_level") else "不存在")
    print("重置後軌道護盾數量: ", test_scene.get_meta("orbital_shields").size() if test_scene.has_meta("orbital_shields") else 0)

    # 測試重置後的升級
    print("\n測試重置後的升級...")
    orbital_shield_upgrade(test_scene)
    print("重置後第一次升級等級: ", test_scene.get_meta("orbital_shield_level"))
    print("重置後第一次升級數量: ", test_scene.get_meta("orbital_shields").size())

    print("=== 軌道護盾修復測試完成 ===")
    quit()

func orbital_shield_upgrade(scene: Node2D) -> void:
    """模擬修復後的軌道護盾升級邏輯"""
    # 獲取當前衛星盾等級，如果不存在則為0
    var shield_level = 0
    if scene.has_meta("orbital_shield_level"):
        shield_level = scene.get_meta("orbital_shield_level")

    # 增加等級
    shield_level += 1
    scene.set_meta("orbital_shield_level", shield_level)

    # 創建新的軌道護盾小球
    var shield = Area2D.new()
    shield.name = "OrbitalShield_%d" % (shield_level - 1)

    # 添加基本屬性
    shield.set_meta("orbital_distance", 100.0)
    shield.set_meta("orbital_speed", 2.0)
    shield.set_meta("orbital_angle", 0.0)
    shield.set_meta("ball_index", shield_level - 1)
    shield.set_meta("total_balls", shield_level)

    # 添加到列表
    if not scene.has_meta("orbital_shields"):
        scene.set_meta("orbital_shields", [])
    scene.get_meta("orbital_shields").append(shield)

func reset_orbital_shields(scene: Node2D) -> void:
    """模擬修復後的軌道護盾重置邏輯"""
    if scene.has_meta("orbital_shield_level"):
        scene.remove_meta("orbital_shield_level")
    if scene.has_meta("orbital_shields"):
        var shields = scene.get_meta("orbital_shields")
        for shield in shields:
            if is_instance_valid(shield):
                shield.queue_free()
        scene.remove_meta("orbital_shields")