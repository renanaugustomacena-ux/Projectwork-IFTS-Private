## test_shop — negozio, inventario e moltiplicatore attrezzi (fase economia).
extends "res://tests/integration/test_base.gd"

var _saved_coins: int = 0
var _saved_items: Array = []


func _snapshot() -> void:
	_saved_coins = int(SaveManager.inventory_data.get("coins", 0))
	_saved_items = (SaveManager.inventory_data.get("items", []) as Array).duplicate(true)


func _restore() -> void:
	SaveManager.inventory_data["coins"] = _saved_coins
	SaveManager.inventory_data["items"] = _saved_items.duplicate(true)


func test_shop_catalog_loaded() -> void:
	assert_true(GameManager.get_shop_section("tools").size() >= 3, "tools section from data/shop.json")
	assert_true(GameManager.get_shop_section("food_player").size() >= 3, "player food section")
	assert_false(GameManager.get_shop_entry("cat_kibble").is_empty(), "cat food entry exists")
	assert_true(GameManager.get_shop_entry("nonexistent").is_empty(), "unknown id is empty dict")


func test_purchase_decrements_coins_and_grants_item() -> void:
	_snapshot()
	SaveManager.inventory_data["coins"] = 100
	SaveManager.inventory_data["items"] = []
	var price := int(GameManager.get_shop_entry("rag").get("price", 0))
	var ok := GameManager.purchase_item("rag")
	assert_true(ok, "purchase with enough coins succeeds")
	assert_eq(int(SaveManager.inventory_data["coins"]), 100 - price, "rag costs its catalog price")
	assert_eq(SaveManager.get_item_qty("rag"), 1, "rag owned after purchase")
	_restore()


func test_purchase_refused_when_poor() -> void:
	_snapshot()
	SaveManager.inventory_data["coins"] = 5
	SaveManager.inventory_data["items"] = []
	assert_false(GameManager.purchase_item("vacuum"), "vacuum costs 200, refused")
	assert_eq(int(SaveManager.inventory_data["coins"]), 5, "coins untouched on refusal")
	assert_eq(SaveManager.get_item_qty("vacuum"), 0)
	assert_false(GameManager.purchase_item("nonexistent"), "unknown item refused")
	_restore()


func test_consume_item_lifecycle() -> void:
	_snapshot()
	SaveManager.inventory_data["items"] = []
	SaveManager.add_item("tea", 2)
	assert_eq(SaveManager.get_item_qty("tea"), 2)
	assert_true(SaveManager.consume_item("tea"))
	assert_eq(SaveManager.get_item_qty("tea"), 1)
	assert_true(SaveManager.consume_item("tea"))
	assert_eq(SaveManager.get_item_qty("tea"), 0, "entry removed at zero")
	assert_false(SaveManager.consume_item("tea"), "cannot consume what you do not own")
	_restore()


func test_best_tool_multiplier_progression() -> void:
	_snapshot()
	SaveManager.inventory_data["items"] = []
	assert_approx(GameManager.best_tool_multiplier(), 1.0, 0.001, "bare hands")
	SaveManager.add_item("rag")
	assert_approx(GameManager.best_tool_multiplier(), 1.5, 0.001)
	SaveManager.add_item("vacuum")
	assert_approx(GameManager.best_tool_multiplier(), 4.0, 0.001, "best owned wins")
	SaveManager.add_item("broom")
	assert_approx(GameManager.best_tool_multiplier(), 4.0, 0.001, "lesser tool does not regress")
	_restore()
