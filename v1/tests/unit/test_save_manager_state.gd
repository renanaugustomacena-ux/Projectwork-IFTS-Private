## TestSaveManagerState — Unit tests for SaveManager game state defaults.
##
## Documentation:
## Verifies default values for decorations, character data, and inventory
## data against the v4.0.0 schema.
class_name TestSaveManagerState
extends GdUnitTestSuite

# --- Decorations ---


func test_decorations_default_is_array() -> void:
	assert_array(SaveManager.decorations).is_not_null()


# --- Character data defaults ---


func test_character_data_has_required_keys() -> void:
	assert_dict(SaveManager.character_data).contains_keys(
		["nome", "genere", "colore_occhi", "colore_capelli", "colore_pelle", "livello_stress"]
	)


func test_character_data_nome_default_is_empty() -> void:
	var nome: String = SaveManager.character_data["nome"]
	assert_str(nome).is_empty()


func test_character_data_livello_stress_default_is_zero() -> void:
	var stress: int = SaveManager.character_data["livello_stress"]
	assert_int(stress).is_equal(0)


# --- Inventory data defaults ---


func test_inventory_data_has_required_keys() -> void:
	assert_dict(SaveManager.inventory_data).contains_keys(["coins", "capacita", "items"])


func test_inventory_data_coins_default_is_zero() -> void:
	var coins: int = SaveManager.inventory_data["coins"]
	assert_int(coins).is_equal(0)


func test_inventory_data_capacita_default_is_positive() -> void:
	var capacita: int = SaveManager.inventory_data["capacita"]
	assert_int(capacita).is_greater(0)


func test_inventory_data_items_default_is_empty_array() -> void:
	assert_array(SaveManager.inventory_data["items"]).is_not_null()
	assert_array(SaveManager.inventory_data["items"]).is_empty()
