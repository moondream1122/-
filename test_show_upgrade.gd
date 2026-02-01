extends SceneTree

func _init():
    print("=== Upgrade screen visibility test start ===")

    var main_scene = load("res://main.tscn").instantiate()
    add_child(main_scene)

    if main_scene.has_method("show_upgrade_screen"):
        main_scene.show_upgrade_screen()
    else:
        print("main_scene missing show_upgrade_screen() method")

    # 等待短暫時間讓輸出刷出
    await get_tree().create_timer(0.2).timeout

    if main_scene.has_method("_reset_game_state"):
        main_scene._reset_game_state()
        print("[DEBUG] Called _reset_game_state() on main_scene")

    await get_tree().create_timer(0.2).timeout
    print("=== Upgrade screen visibility test end ===")
    quit()
