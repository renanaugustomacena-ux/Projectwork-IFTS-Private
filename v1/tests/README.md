# Mini Cozy Room — Test Unitari

> **Nota sulla Semplificazione**: I test esistenti coprono moduli essenziali (Helpers, SaveManager)
> e moduli che potrebbero essere semplificati in futuro (Logger). Se un modulo testato viene
> semplificato o rimosso, i relativi test dovranno essere aggiornati di conseguenza.
> I nuovi test proposti nell'audit report per moduli come AudioManager e GameManager
> restano validi indipendentemente dalla semplificazione.

Questa cartella contiene **5 test suite** basate sul framework **GdUnit4** per Godot 4.x.
I test verificano funzioni utility, comportamento degli autoload, integrita del sistema
di salvataggio e logica del pannello negozio.

Tutti i test vengono eseguiti in CI tramite GitHub Actions (`ci.yml`).

## Framework

- **GdUnit4** — Test runner GDScript per Godot 4.x
- **Classe base**: `GdUnitTestSuite`
- **Convenzione metodi**: `func test_<descrizione>() -> void`
- **Assertion**: API fluent GdUnit4 (`assert_str`, `assert_int`, `assert_bool`, `assert_array`, ecc.)

## Struttura

```
tests/
└── unit/
    ├── test_helpers.gd               # Funzioni utility (Helpers)
    ├── test_logger.gd                # Logging strutturato (AppLogger)
    ├── test_save_manager.gd          # Struttura salvataggio e settings (SaveManager)
    ├── test_save_manager_state.gd    # Stato di gioco defaults (SaveManager)
    └── test_shop_panel.gd            # Catalogo e segnali negozio (ShopPanel)
```

## Dettaglio Test Suite

### test_helpers.gd

Test per le funzioni utility in `scripts/utils/helpers.gd` (`class_name Helpers`).

| Area | Test | Descrizione |
|------|------|-------------|
| Serializzazione | `test_vec2_to_array_*` | Vector2 → Array per salvataggio JSON |
| Serializzazione | `test_array_to_vec2_*` | Array → Vector2 (deserializzazione) |
| Serializzazione | `test_array_to_vec2_roundtrip` | Round-trip serializzazione/deserializzazione |
| Viewport | `test_clamp_to_viewport_*` | Clamping posizioni entro viewport (1280x720) |
| Formattazione | `test_format_time_*` | Formattazione secondi → MM:SS |
| Formattazione | `test_get_date_string_*` | Formato data ISO YYYY-MM-DD |

### test_logger.gd

Test per il sistema di logging in `scripts/autoload/logger.gd` (`AppLogger`).

| Area | Test | Descrizione |
|------|------|-------------|
| Session | `test_session_id_*` | Formato e validita session ID |
| Configurazione | `test_min_level_*` | Livello minimo log configurabile |
| Livelli | `test_level_enum_*` | Ordinamento DEBUG < INFO < WARN < ERROR |
| File | `test_log_file_path_*` | Percorso file log (`user://logs/*.jsonl`) |
| Costanti | `test_max_log_*`, `test_flush_*` | Dimensione, numero file, intervallo flush |

### test_save_manager.gd

Test per la struttura del salvataggio in `scripts/autoload/save_manager.gd`.

| Area | Test | Descrizione |
|------|------|-------------|
| Costanti | `test_save_version`, `test_save_path`, `test_backup_path` | Struttura dati v4.0.0 |
| Auto-save | `test_auto_save_interval` | Intervallo auto-save positivo |
| Settings | `test_settings_*` | Default settings: lingua, volume, display mode |
| Musica | `test_music_state_*` | Default stato musicale: traccia, playlist, ambience |

### test_save_manager_state.gd

Test per i valori default dello stato di gioco in `SaveManager`.

| Area | Test | Descrizione |
|------|------|-------------|
| Decorazioni | `test_decorations_*` | Default decorazioni (array non null) |
| Personaggio | `test_character_data_*` | Default: chiavi presenti, nome vuoto, stress 0 |
| Inventario | `test_inventory_data_*` | Default: coins 0, capacita > 0, items vuoto |

### test_shop_panel.gd

Test per il pannello negozio e l'integrazione con il catalogo.

| Area | Test | Descrizione |
|------|------|-------------|
| Catalogo | `test_decorations_catalog_*` | Catalogo ha categorie e oggetti |
| Segnali | `test_shop_item_selected_signal` | Segnale `shop_item_selected` dichiarato in SignalBus |
| Scena | `test_shop_panel_scene_*` | Scena shop registrata e file `.tscn` valido |

## Esecuzione

### Locale (da Godot Editor)

Aprire il **Bottom Panel** → **GdUnit4** → **Run All**.

### CI/CD

- **Workflow**: `.github/workflows/ci.yml`
- **Container**: `barichello/godot-ci:4.5`
- **Trigger**: push su branch `Renan`, PR su `main`
- **Sequenza**: lint (gdlint + gdformat) → test (GdUnit4) → security scan

## Copertura Attuale

| Modulo | Script Testato | Copertura | Suite |
|--------|---------------|-----------|-------|
| Helpers | `utils/helpers.gd` | Completa | test_helpers.gd |
| Logger | `autoload/logger.gd` | Parziale (logica interna, no I/O) | test_logger.gd |
| SaveManager | `autoload/save_manager.gd` | Parziale (struttura + defaults) | test_save_manager.gd, test_save_manager_state.gd |
| ShopPanel | `ui/shop_panel.gd` | Base (catalogo + segnali) | test_shop_panel.gd |

## Vedi Anche

- [README Script](../scripts/README.md) — I moduli verificati da questi test
- [README Tecnico](../README.md) — Pipeline CI/CD e convenzioni di sviluppo
