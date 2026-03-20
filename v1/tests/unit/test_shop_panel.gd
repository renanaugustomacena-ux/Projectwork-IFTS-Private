## TestShopPanel — Unit tests for the ShopPanel catalog browser.
##
## Documentation:
## Verifies that the shop panel can access the decorations catalog
## and that the shop signal is properly declared in SignalBus.
class_name TestShopPanel
extends GdUnitTestSuite

# --- Catalog data availability ---


func test_decorations_catalog_has_categories() -> void:
	var catalog: Dictionary = GameManager.decorations_catalog
	assert_array(catalog.get("categories", [])).is_not_empty()


func test_decorations_catalog_has_items() -> void:
	var catalog: Dictionary = GameManager.decorations_catalog
	assert_array(catalog.get("decorations", [])).is_not_empty()


# --- Shop signal ---


func test_shop_item_selected_signal_exists() -> void:
	assert_bool(SignalBus.has_signal("shop_item_selected")).is_true()


# --- Panel registration ---


func test_shop_panel_scene_registered() -> void:
	assert_bool(PanelManager.PANEL_SCENES.has("shop")).is_true()


func test_shop_panel_scene_path_is_valid() -> void:
	var path: String = PanelManager.PANEL_SCENES.get("shop", "")
	assert_bool(ResourceLoader.exists(path)).is_true()
